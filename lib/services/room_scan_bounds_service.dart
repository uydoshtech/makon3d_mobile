import "package:room_scan_kit/room_scan_kit.dart";

import "package:makon3d_mobile/base/ios_device.dart";

/// Host wrapper around [RoomScanBounds] from `room_scan_kit`.
class RoomScanBoundsService {
  RoomScanBoundsService._();

  static Future<RoomScanMetrics?> computeFromUsdPath(String path) async {
    if (!isIOSDevice) return null;
    return RoomScanBounds.computeFromUsdPath(path);
  }
}
