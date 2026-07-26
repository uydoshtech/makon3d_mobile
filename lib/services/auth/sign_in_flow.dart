import "dart:async";

import "package:firebase_auth/firebase_auth.dart";

import "package:makon3d_mobile/services/auth/apple_auth_service.dart";
import "package:makon3d_mobile/services/auth/auth_api.dart";
import "package:makon3d_mobile/services/auth/auth_state.dart";
import "package:makon3d_mobile/services/auth/google_auth_service.dart";
import "package:makon3d_mobile/services/auth/telegram_native_login_service.dart";

/// End-to-end sign-in flows: provider → (Firebase) → backend session →
/// [AuthState]. Each returns `true` on success and `false` when the user
/// cancels; provider/network errors propagate to the caller for display.
abstract final class SignInFlow {
  static Future<bool> signInWithApple() async {
    final result = await AppleAuthService().signInWithApple();
    if (result == null) return false;

    final user = result.userCredential.user;
    if (user == null) throw Exception("Apple sign-in returned no user");
    await _mintBackendSession(user, method: "apple");

    // Fire-and-forget after the session token exists (the endpoint needs
    // the Bearer token); failures are logged inside [AuthApi.appleBind].
    final authorizationCode = result.authorizationCode;
    if (authorizationCode != null && authorizationCode.isNotEmpty) {
      unawaited(AuthApi.appleBind(authorizationCode: authorizationCode));
    }
    return true;
  }

  static Future<bool> signInWithGoogle() async {
    final credential = await GoogleAuthService.signIn();
    if (credential == null) return false;

    final user = credential.user;
    if (user == null) throw Exception("Google sign-in returned no user");
    await _mintBackendSession(user, method: "google");
    return true;
  }

  static Future<bool> signInWithTelegram() async {
    final idToken = await TelegramNativeLoginService.instance.login();
    if (idToken == null) return false;

    final session = await AuthApi.telegramAuth(idToken: idToken);
    await AuthState().onSignedIn(session: session, method: "telegram");
    return true;
  }

  static Future<void> _mintBackendSession(
    User user, {
    required String method,
  }) async {
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception("Firebase returned an empty ID token");
    }
    final session = await AuthApi.firebaseAuth(
      email: user.email ?? "",
      firebaseUid: user.uid,
      idToken: idToken,
      avatarUrl: user.photoURL,
    );
    await AuthState().onSignedIn(
      session: session,
      displayName: user.displayName,
      avatarUrl: user.photoURL,
      method: method,
    );
  }
}
