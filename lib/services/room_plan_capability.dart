import "package:flutter_roomplan/flutter_roomplan.dart";

import "package:makon3d_mobile/base/ios_device.dart";

/// RoomPlan / LiDAR is only available on some iOS devices
/// ([FlutterRoomplan.isSupported]). Cached for the lifetime of the isolate.
abstract final class RoomPlanCapability {
  static final FlutterRoomplan _roomPlan = FlutterRoomplan();
  static Future<bool>? _future;

  static Future<bool> isSupportedOnDevice() {
    if (!isIOSDevice) return Future<bool>.value(false);
    return _future ??= _query();
  }

  static Future<bool> _query() async {
    try {
      return await _roomPlan.isSupported();
    } catch (_) {
      return false;
    }
  }
}
