import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "package:makon3d_mobile/services/scan_upload_service.dart";

/// Reverse geocoding via the backend's anonymous Yandex Geocoder proxy
/// (`GET /makon3d/geocode/reverse`) — the same proxy (and address formatting)
/// the UyDosh app's create-listing screen uses, minus the JWT.
class GeocodeService {
  GeocodeService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ScanUploadService.basePath,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

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
