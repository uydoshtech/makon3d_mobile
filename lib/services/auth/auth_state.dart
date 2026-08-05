import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";
import "package:google_sign_in/google_sign_in.dart";

import "package:makon3d_mobile/models/makon_user_role.dart";
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
  int? _userId;
  String? _email;
  String? _displayName;
  String? _avatarUrl;
  String? _method;
  MakonUserRole? _makonRole;

  bool get isSignedIn => _signedIn;
  int? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  String? get method => _method;
  MakonUserRole? get makonRole => _makonRole;

  /// Restore the persisted session at app launch (before runApp).
  static Future<void> initialize() async {
    final session = await SessionManager.getSession();
    if (session == null) return;
    // Existing sessions created before avatar persistence was introduced do
    // not have an image in Keychain. Firebase retains Google/Apple identity
    // across launches, so use it to hydrate the image without forcing the
    // user to sign out and back in.
    final firebasePhoto = FirebaseBootstrap.isReady
        ? FirebaseAuth.instance.currentUser?.photoURL
        : null;
    final avatarUrl = session.avatarUrl?.trim().isNotEmpty == true
        ? session.avatarUrl
        : firebasePhoto;
    _instance
      .._signedIn = true
      .._userId = session.userId
      .._email = session.email
      .._displayName = session.displayName
      .._avatarUrl = avatarUrl
      .._method = session.method
      .._makonRole = session.makonRole;

    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      await SessionManager.saveSession(
        token: session.token,
        userId: session.userId,
        email: session.email,
        displayName: session.displayName,
        avatarUrl: avatarUrl,
        method: session.method,
        makonRole: session.makonRole,
      );
    }
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
      makonRole: session.makonRole,
    );
    _signedIn = true;
    _userId = session.userId;
    _email = session.email;
    _displayName = name;
    _avatarUrl = photo;
    _method = method;
    _makonRole = session.makonRole;
    notifyListeners();
  }

  /// Best-effort refresh for sessions persisted by older app versions and
  /// for role changes made on another device.
  Future<void> refreshMakonRole() async {
    if (!_signedIn) return;
    try {
      final role = await AuthApi.fetchMakonRole();
      if (role == _makonRole) return;
      _makonRole = role;
      await _persistCurrentSession();
      notifyListeners();
    } catch (e) {
      debugPrint("Makon role refresh failed (non-fatal): $e");
    }
  }

  Future<void> setMakonRole(MakonUserRole role) async {
    if (!_signedIn) throw StateError("Sign in before selecting a Makon role.");
    final saved = await AuthApi.updateMakonRole(role);
    _makonRole = saved;
    await _persistCurrentSession();
    notifyListeners();
  }

  Future<void> _persistCurrentSession() async {
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty || _userId == null) return;
    await SessionManager.saveSession(
      token: token,
      userId: _userId!,
      email: _email,
      displayName: _displayName,
      avatarUrl: _avatarUrl,
      method: _method,
      makonRole: _makonRole,
    );
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
    _userId = null;
    _email = null;
    _displayName = null;
    _avatarUrl = null;
    _method = null;
    _makonRole = null;
    notifyListeners();
  }
}
