import "package:firebase_auth/firebase_auth.dart";
import "package:google_sign_in/google_sign_in.dart";

/// Google sign-in → Firebase credential exchange (google_sign_in 7.x flow,
/// same as UyDosh's auth wizard).
///
/// On iOS the plugin reads its OAuth client id from
/// `GoogleService-Info.plist`, so no client id is passed here.
abstract final class GoogleAuthService {
  static Future<void>? _initFuture;

  /// google_sign_in 7.x requires [GoogleSignIn.initialize] to be awaited
  /// exactly once before any other call; this is the single call site.
  static Future<void> ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize();
  }

  /// Runs the interactive Google sign-in and exchanges the result for a
  /// Firebase session. Returns `null` if the user dismisses the sheet.
  static Future<UserCredential?> signIn() async {
    await ensureInitialized();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      // 7.x throws instead of returning null on dismissal.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }

    // Authentication tokens are synchronous in 7.x; authorization tokens
    // (accessToken) are a separate step not needed for Firebase.
    final credential = GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }
}
