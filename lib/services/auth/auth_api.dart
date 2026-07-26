import "package:dio/dio.dart";
import "package:flutter/foundation.dart" show debugPrint;

import "package:makon3d_mobile/services/auth/session_manager.dart";

/// Parsed response of the UyDosh session-minting endpoints
/// (`/users/firebase-auth`, `/users/telegram-auth`).
class BackendSession {
  const BackendSession({
    required this.sessionToken,
    required this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String sessionToken;
  final int userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  factory BackendSession.fromJson(Map<String, dynamic> json) {
    final token = json["sessionToken"];
    if (token is! String || token.isEmpty) {
      throw Exception("Backend auth response is missing sessionToken");
    }
    final user = json["user"];
    final userMap =
        user is Map ? Map<String, dynamic>.from(user) : const <String, dynamic>{};
    final profile = json["profile"];
    final profileMap =
        profile is Map ? Map<String, dynamic>.from(profile) : const <String, dynamic>{};
    return BackendSession(
      sessionToken: token,
      userId: (userMap["id"] as num?)?.toInt() ?? 0,
      email: userMap["email"] as String?,
      displayName: profileMap["full_name"] as String?,
      avatarUrl: profileMap["avatar_url"] as String?,
    );
  }
}

/// Auth endpoints on the shared UyDosh backend. Same contracts as the
/// UyDosh app's `AuthService`; both apps mint sessions against the same
/// `/users` table (shared identity by design).
abstract final class AuthApi {
  static const String basePath = String.fromEnvironment(
    "API_BASE_PATH",
    defaultValue: "https://api.uydosh.com",
  );

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: basePath,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SessionManager.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          handler.next(options);
        },
      ),
    );

  /// POST `/users/firebase-auth` — provider-agnostic (Google and Apple both
  /// arrive here after Firebase sign-in; the backend only verifies the
  /// Firebase ID token).
  static Future<BackendSession> firebaseAuth({
    required String email,
    required String firebaseUid,
    required String idToken,
    String? avatarUrl,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      "/users/firebase-auth",
      data: <String, dynamic>{
        "email": email,
        "firebase_uid": firebaseUid,
        "id_token": idToken,
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          "avatar_url": avatarUrl.trim(),
      },
    );
    return BackendSession.fromJson(response.data ?? const {});
  }

  /// POST `/users/telegram-auth` with the JWT id_token from the native
  /// Telegram Login SDK.
  static Future<BackendSession> telegramAuth({required String idToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      "/users/telegram-auth",
      data: <String, dynamic>{"id_token": idToken},
    );
    return BackendSession.fromJson(response.data ?? const {});
  }

  /// Best-effort: forward Apple's one-shot `authorization_code` so the
  /// backend can persist a refresh token for revocation at account-deletion
  /// time (App Review Guideline 5.1.1(v)). Must run after the session token
  /// is saved (the endpoint requires a Bearer token) and must never block
  /// sign-in.
  static Future<void> appleBind({required String authorizationCode}) async {
    try {
      await _dio.post<void>(
        "/users/apple-bind",
        data: <String, dynamic>{"authorization_code": authorizationCode},
      );
    } catch (e) {
      debugPrint("Apple bind (non-fatal): $e");
    }
  }
}
