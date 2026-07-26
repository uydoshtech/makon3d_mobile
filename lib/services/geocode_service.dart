import "dart:math";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "package:makon3d_mobile/services/scan_upload_service.dart";

/// A Yandex address suggestion returned by the backend proxy.
class AddressSuggestion {
  const AddressSuggestion({required this.address, this.subtitle});

  final String address;
  final String? subtitle;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    final address = json["address"];
    final title = json["title"];
    final subtitle = json["subtitle"];
    final addressMap = address is Map
        ? Map<String, dynamic>.from(address)
        : const <String, dynamic>{};
    final titleMap = title is Map
        ? Map<String, dynamic>.from(title)
        : const <String, dynamic>{};
    final subtitleMap = subtitle is Map
        ? Map<String, dynamic>.from(subtitle)
        : const <String, dynamic>{};
    final display = (addressMap["formatted_address"] as String?)?.trim();
    final fallback = (titleMap["text"] as String?)?.trim();
    return AddressSuggestion(
      address: display?.isNotEmpty == true ? display! : (fallback ?? ""),
      subtitle: (subtitleMap["text"] as String?)?.trim(),
    );
  }
}

/// Reverse geocoding via the backend's anonymous Yandex Geocoder proxy
/// (`GET /makon3d/geocode/*`) — the same server-side Yandex key and address
/// formatting used by UyDosh, without exposing the key to the mobile app.
class GeocodeService {
  GeocodeService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ScanUploadService.basePath,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Builds a per-field Yandex session token for grouping autocomplete
  /// requests. It is an opaque, non-user identifier and never leaves the
  /// request URL except as Yandex's expected `sessiontoken` parameter.
  static String newSuggestSessionToken() {
    final random = Random.secure();
    final suffix = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, "0")).join();
    return "${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix";
  }

  /// Gets up to six Uzbekistan-biased Yandex address suggestions. Returns an
  /// empty list for a short query or any unavailable/network response so the
  /// free-form address field always remains usable.
  static Future<List<AddressSuggestion>> suggest({
    required String text,
    required String sessionToken,
    required String lang,
  }) async {
    final query = text.trim();
    if (query.length < 2) return const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        "/makon3d/geocode/suggest",
        queryParameters: <String, dynamic>{
          "text": query,
          "sessiontoken": sessionToken,
          "lang": lang,
          "results": 6,
        },
      );
      final raw = response.data?["results"];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (entry) =>
                AddressSuggestion.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where((suggestion) => suggestion.address.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint("GeocodeService suggest failed: $e");
      return const [];
    }
  }

  /// Resolves coordinates into a human-readable address; null when the
  /// lookup fails or Yandex has nothing for the point.
  static Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
    required String lang,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        "/makon3d/geocode/reverse",
        queryParameters: <String, dynamic>{
          "latitude": latitude,
          "longitude": longitude,
          "lang": lang,
        },
      );
      final address = response.data?["addressText"];
      if (address is String && address.trim().isNotEmpty) {
        return address.trim();
      }
      return null;
    } catch (e) {
      debugPrint("GeocodeService reverse failed: $e");
      return null;
    }
  }
}
