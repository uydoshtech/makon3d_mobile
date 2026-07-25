import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart"
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import "package:sign_in_with_apple/sign_in_with_apple.dart";

/// Result of a successful Apple sign-in: the Firebase [UserCredential]
/// plus the one-shot `authorizationCode` Apple returned. The auth code is
/// short-lived (~5 min) and single-use — the caller MUST forward it to
/// `/users/apple-bind` immediately so the backend can persist a refresh
/// token for revocation at account-deletion time (Guideline 5.1.1(v)).
class AppleSignInResult {
  AppleSignInResult({
    required this.userCredential,
    required this.authorizationCode,
  });

  final UserCredential userCredential;
  final String? authorizationCode;
}

/// Sign in with Apple → Firebase credential exchange. Ported from UyDosh's
/// `AppleAuthService` (same nonce handling and first-sign-in name capture).
///
/// Apple-specific quirks worth knowing:
///
/// * Apple returns the user's full name and email **only on the very first
///   sign-in** for a given Apple ID + bundle. We push `givenName` /
///   `familyName` onto the Firebase user via [User.updateDisplayName] so
///   subsequent logins still see them.
/// * "Hide My Email" yields a `@privaterelay.appleid.com` address — treat
///   it as a normal email.
/// * Firebase requires the **raw nonce** whose SHA-256 was sent to Apple;
///   without it the credential is rejected with `invalid_nonce`.
class AppleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// SIWA is native-only (iOS/macOS). Makon3D ships iOS-only anyway.
  static bool get isAvailable {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String _generateRawNonce({int length = 32}) {
    const charset =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._";
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  /// Trigger the native Sign in with Apple flow and exchange the result for
  /// a Firebase session. Returns `null` if the user cancels at the system
  /// sheet.
  Future<AppleSignInResult?> signInWithApple() async {
    if (!isAvailable) return null;

    final rawNonce = _generateRawNonce();
    final hashedNonce = _sha256(rawNonce);

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint("Apple sign-in cancelled by user");
        return null;
      }
      rethrow;
    }

    final identityToken = appleCredential.identityToken;
    final authorizationCode = appleCredential.authorizationCode;

    if (identityToken == null) {
      // Should be unreachable on a successful flow, but Apple has shipped
      // this nil before — fail loudly rather than passing null to Firebase.
      throw FirebaseAuthException(
        code: "invalid-credential",
        message: "Apple ID credential was missing an identityToken",
      );
    }

    // Prefer `idToken` + `rawNonce` per Firebase native docs; some
    // FlutterFire stacks still expect `accessToken` here — without it you
    // can get `invalid-credential` despite a valid JWT.
    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: identityToken,
      rawNonce: rawNonce,
      accessToken: authorizationCode.isNotEmpty ? authorizationCode : null,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);

    // Capture the one-shot name from the first sign-in (see class doc).
    final user = userCredential.user;
    if (user != null) {
      final newDisplayName = _composeDisplayName(
        appleCredential.givenName,
        appleCredential.familyName,
      );
      if (newDisplayName != null && (user.displayName ?? "").trim().isEmpty) {
        try {
          await user.updateDisplayName(newDisplayName);
          await user.reload();
        } catch (e) {
          debugPrint("Apple sign-in: updateDisplayName failed: $e");
        }
      }
    }

    return AppleSignInResult(
      userCredential: userCredential,
      authorizationCode: authorizationCode,
    );
  }

  String? _composeDisplayName(String? given, String? family) {
    final parts = <String>[
      if (given != null && given.trim().isNotEmpty) given.trim(),
      if (family != null && family.trim().isNotEmpty) family.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(" ");
  }
}
