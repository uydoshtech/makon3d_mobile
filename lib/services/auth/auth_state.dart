import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";
import "package:google_sign_in/google_sign_in.dart";

import "package:makon3d_mobile/services/auth/auth_api.dart";
import "package:makon3d_mobile/services/auth/firebase_bootstrap.dart";
import "package:makon3d_mobile/services/auth/session_manager.dart";

/// Global signed-in/out state, same singleton-ChangeNotifier pattern as
/// [LanguageState]. Signed in == a backend session token is stored;
/// Firebase state is a means to mint that token, not the source of truth.
class AuthState extends ChangeNotifier {
  AuthState._();

  static final AuthState _instance = AuthState._();
  factory AuthState() => _instance;

  bool _signedIn = false;
  String? _email;
  String? _displayName;
  String? _avatarUrl;
  String? _method;

  bool get isSignedIn => _signedIn;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  String? get method => _method;

  /// Restore the persisted session at app launch (before runApp).
  static Future<void> initialize() async {
    final session = await SessionManager.getSession();
    if (session == null) return;
    _instance
      .._signedIn = true
      .._email = session.email
      .._displayName = session.displayName
      .._avatarUrl = session.avatarUrl
      .._method = session.method;
  }

  /// Persist a freshly minted backend session and flip to signed-in.
  Future<void> onSignedIn({
    required BackendSession session,
    String? displayName,
    String? avatarUrl,
    String? method,
  }) async {
    final name = displayName ?? session.displayName;
    final photo = avatarUrl ?? session.avatarUrl;
    await SessionManager.saveSession(
      token: session.sessionToken,
      userId: session.userId,
      email: session.email,
      displayName: name,
      avatarUrl: photo,
      method: method,
    );
    _signedIn = true;
    _email = session.email;
    _displayName = name;
    _avatarUrl = photo;
    _method = method;
    notifyListeners();
  }

  /// Clear the backend session plus any provider-side state (Firebase,
  /// cached Google account). Provider sign-outs are best-effort — the local
  /// session is always cleared.
  Future<void> signOut() async {
    if (FirebaseBootstrap.isReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint("Firebase sign-out failed (non-fatal): $e");
      }
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint("Google sign-out failed (non-fatal): $e");
      }
    }
    await SessionManager.clearSession();
    _signedIn = false;
    _email = null;
    _displayName = null;
    _avatarUrl = null;
    _method = null;
    notifyListeners();
  }
}
