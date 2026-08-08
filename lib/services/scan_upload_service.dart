import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "package:makon3d_mobile/models/makon_scan.dart";
import "package:makon3d_mobile/models/room_scan_metrics.dart";
import "package:makon3d_mobile/services/auth/session_manager.dart";
import "package:makon3d_mobile/services/device_identity.dart";

class ScanUploadResult {
  const ScanUploadResult({
    required this.id,
    this.usdzUrl,
    this.glbUrl,
    this.wallPerimeterM,
    this.doorwayWidthM,
    this.doorwayAreaM2,
    this.windowAreaM2,
    this.roomTypes = const <String>[],
    this.objectCounts = const <String, int>{},
  });

  final int id;
  final String? usdzUrl;
  final String? glbUrl;

  /// Wall-run metrics the backend measures from the converted GLB — null for
  /// scans where no walls were identified (or older backends).
  final double? wallPerimeterM;
  final double? doorwayWidthM;
  final double? doorwayAreaM2;
  final double? windowAreaM2;
  final List<String> roomTypes;
  final Map<String, int> objectCounts;
}

/// Anonymous scan upload / list against the UyDosh backend (`/makon3d/scans`).
class ScanUploadService {
  ScanUploadService._();

  static const String basePath = String.fromEnvironment(
    "API_BASE_PATH",
    defaultValue: "https://api.uydosh.com",
  );

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: basePath,
      // GLB conversion runs synchronously on the server and RoomPlan USDZ
      // can be tens of MB — mirror UyDosh's 6-minute upload timeouts.
      connectTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(minutes: 6),
      receiveTimeout: const Duration(minutes: 6),
    ),
  );

  static String hostedUrl(String pathOrUrl) {
    final s = pathOrUrl.trim();
    if (s.isEmpty) return s;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return "$basePath$s";
  }

  static Future<ScanUploadResult> uploadScan({
    required String usdzFilePath,
    RoomScanMetrics? metrics,
  }) async {
    final file = File(usdzFilePath);
    if (!file.existsSync()) {
      throw Exception("USDZ file not found: $usdzFilePath");
    }
    final bytes = await file.readAsBytes();
    final deviceId = await DeviceIdentity.get();
    final response = await _dio.post<Map<String, dynamic>>(
      "/makon3d/scans",
      data: <String, dynamic>{
        "usdzData": base64Encode(bytes),
        "device_id": deviceId,
        if (metrics != null) "room_scan_metrics": metrics.toJson(),
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return ScanUploadResult(
      id: (data["id"] as num?)?.toInt() ?? 0,
      usdzUrl: data["usdzUrl"] as String?,
      glbUrl: data["glbUrl"] as String?,
      wallPerimeterM: (data["wallPerimeterM"] as num?)?.toDouble(),
      doorwayWidthM: (data["doorwayWidthM"] as num?)?.toDouble(),
      doorwayAreaM2: (data["doorwayAreaM2"] as num?)?.toDouble(),
      windowAreaM2: (data["windowAreaM2"] as num?)?.toDouble(),
      roomTypes:
          (data["roomTypes"] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
      objectCounts:
          (data["objectCounts"] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          ) ??
          const <String, int>{},
    );
  }

  /// Scans uploaded from this install only — used by the legacy-scan →
  /// project migration, which must not import other people's scans.
  static Future<List<MakonScan>> listScansForThisDevice({
    CancelToken? cancelToken,
  }) async {
    final deviceId = await DeviceIdentity.get();
    return _listScans(
      queryParameters: <String, dynamic>{"device_id": deviceId},
      cancelToken: cancelToken,
    );
  }

  /// All recent public scans across devices — the Scans tab shows everything
  /// for now (same feed as the Makon3D web gallery / Telegram bot).
  static Future<List<MakonScan>> listAllScans({CancelToken? cancelToken}) {
    return _listScans(cancelToken: cancelToken);
  }

  /// Deletes a scan from the backend gallery (row + media files). Throws on
  /// failure so callers can surface an error toast.
  static Future<void> deleteScan(int scanId) async {
    await _dio.delete<void>(
      "/makon3d/scans/$scanId",
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  static Future<MakonScan> getScan(int scanId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      "/makon3d/scans/$scanId",
    );
    return MakonScan.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Push furniture / surface edits for a remote scan (signed-in only).
  /// [furnitureEdits] null clears the stored document.
  static Future<void> patchFurnitureEdits(
    int scanId,
    Map<String, dynamic>? furnitureEdits,
  ) async {
    if (scanId <= 0) return;
    final token = await SessionManager.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await _dio.patch<void>(
        "/makon3d/scans/$scanId/furniture-edits",
        data: <String, dynamic>{"furniture_edits": furnitureEdits},
        options: Options(
          headers: <String, dynamic>{"Authorization": "Bearer $token"},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
    } catch (e) {
      debugPrint("ScanUploadService patchFurnitureEdits failed ($scanId): $e");
      rethrow;
    }
  }

  static Future<List<MakonScan>> _listScans({
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      "/makon3d/scans",
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final raw = response.data?["scans"];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => MakonScan.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
