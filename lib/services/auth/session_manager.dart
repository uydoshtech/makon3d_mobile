import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "package:makon3d_mobile/models/makon_user_role.dart";

/// Snapshot of the persisted backend session.
class StoredSession {
  const StoredSession({
    required this.token,
    required this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.method,
    this.makonRole,
  });

  final String token;
  final int userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  /// "apple" | "google" | "telegram" — informational only.
  final String? method;
  final MakonUserRole? makonRole;
}

/// Persists the UyDosh backend session (`sessionToken` from
/// `/users/firebase-auth` / `/users/telegram-auth`).
///
/// Unlike UyDosh (plain SharedPreferences) the token lives in the iOS
/// Keychain via flutter_secure_storage — same storage the app already uses
/// for [DeviceIdentity].
abstract final class SessionManager {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "makon3d_session_token";
  static const _userIdKey = "makon3d_session_user_id";
  static const _emailKey = "makon3d_session_email";
  static const _nameKey = "makon3d_session_name";
  static const _avatarUrlKey = "makon3d_session_avatar_url";
  static const _methodKey = "makon3d_session_method";
  static const _makonRoleKey = "makon3d_session_makon_role";

  static String? _cachedToken;
  static bool _tokenLoaded = false;

  static Future<void> saveSession({
    required String token,
    required int userId,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? method,
    MakonUserRole? makonRole,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _writeOrDelete(_emailKey, email);
    await _writeOrDelete(_nameKey, displayName);
    await _writeOrDelete(_avatarUrlKey, avatarUrl);
    await _writeOrDelete(_methodKey, method);
    await _writeOrDelete(_makonRoleKey, makonRole?.apiValue);
    _cachedToken = token;
    _tokenLoaded = true;
  }

  /// Cached after first read; the auth interceptor calls this per request.
  static Future<String?> getToken() async {
    if (_tokenLoaded) return _cachedToken;
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
    } catch (_) {
      _cachedToken = null;
    }
    _tokenLoaded = true;
    return _cachedToken;
  }

  static Future<StoredSession?> getSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;
    String? userIdRaw;
    String? email;
    String? name;
    String? avatarUrl;
    String? method;
    String? makonRole;
    try {
      userIdRaw = await _storage.read(key: _userIdKey);
      email = await _storage.read(key: _emailKey);
      name = await _storage.read(key: _nameKey);
      avatarUrl = await _storage.read(key: _avatarUrlKey);
      method = await _storage.read(key: _methodKey);
      makonRole = await _storage.read(key: _makonRoleKey);
    } catch (_) {
      // Keychain hiccup — token alone is still a valid session.
    }
    return StoredSession(
      token: token,
      userId: int.tryParse(userIdRaw ?? "") ?? 0,
      email: email,
      displayName: name,
      avatarUrl: avatarUrl,
      method: method,
      makonRole: MakonUserRole.fromApi(makonRole),
    );
  }

  static Future<void> clearSession() async {
    _cachedToken = null;
    _tokenLoaded = true;
    for (final key in [
      _tokenKey,
      _userIdKey,
      _emailKey,
      _nameKey,
      _avatarUrlKey,
      _methodKey,
      _makonRoleKey,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // Best-effort; an orphaned metadata key without a token is harmless.
      }
    }
  }

  static Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value.trim());
    }
  }
}
