import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";

import "package:makon3d_mobile/models/room_scan_metrics.dart";
import "package:makon3d_mobile/services/device_identity.dart";

class ScanUploadResult {
  const ScanUploadResult({required this.id, this.usdzUrl, this.glbUrl});

  final int id;
  final String? usdzUrl;
  final String? glbUrl;
}

/// Anonymous scan upload to the UyDosh backend (`POST /makon3d/scans`).
/// The server stores the USDZ, converts it to GLB (Blender pipeline), and
/// keys the record by the anonymous device id.
class ScanUploadService {
  ScanUploadService._();

  static const String _basePath = String.fromEnvironment(
    "API_BASE_PATH",
    defaultValue: "https://api.uydosh.com",
  );

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _basePath,
      // GLB conversion runs synchronously on the server and RoomPlan USDZ
      // can be tens of MB — mirror UyDosh's 6-minute upload timeouts.
      connectTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(minutes: 6),
      receiveTimeout: const Duration(minutes: 6),
    ),
  );

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
    );
  }
}
