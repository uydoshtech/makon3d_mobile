import "package:flutter/services.dart";

import "package:makon3d_mobile/base/ios_device.dart";
import "package:makon3d_mobile/models/room_scan_metrics.dart";

/// Reads LiDAR USDZ axis-aligned bounds on iOS (SceneKit); matches the 3D
/// viewer convention. Channel name is shared with the UyDosh native plugin
/// (RoomScanBoundsPlugin.swift), which is copied verbatim into this app.
class RoomScanBoundsService {
  RoomScanBoundsService._();

  static const MethodChannel _channel = MethodChannel("uydosh/room_scan_bounds");

  static Future<RoomScanMetrics?> computeFromUsdPath(String path) async {
    if (!isIOSDevice) return null;
    if (path.isEmpty) return null;
    // RoomPlan may finish writing the USDZ slightly after the capture
    // callback — retry with short delays.
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 350),
      Duration(milliseconds: 800),
    ];
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final metrics = await _computeOnce(path);
      if (metrics != null) {
        return metrics;
      }
    }
    return null;
  }

  static Future<RoomScanMetrics?> _computeOnce(String path) async {
    try {
      final raw = await _channel.invokeMethod<Object?>(
        "computeFromUsdPath",
        <String, dynamic>{"path": path},
      );
      if (raw is! Map) return null;
      final floorLong = (raw["floor_long_m"] as num?)?.toDouble();
      final floorShort = (raw["floor_short_m"] as num?)?.toDouble();
      final height = (raw["height_m"] as num?)?.toDouble();
      final area = (raw["floor_area_m2"] as num?)?.toDouble();
      if (floorLong == null ||
          floorShort == null ||
          height == null ||
          area == null) {
        return null;
      }
      final bearing = (raw["world_plus_x_bearing_deg"] as num?)?.toDouble();
      return RoomScanMetrics(
        floorLongM: floorLong,
        floorShortM: floorShort,
        heightM: height,
        floorAreaM2: area,
        worldPlusXBearingDeg: bearing,
      );
    } on Object {
      return null;
    }
  }
}
