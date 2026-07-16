import "package:room_scan_kit/room_scan_kit.dart";

import "package:makon3d_mobile/base/ios_device.dart";

/// Host wrapper around [NativeLanguage] from `room_scan_kit`.
abstract final class NativeLanguageService {
  static Future<void> setPreferredLanguage(String languageCode) async {
    if (!isIOSDevice) return;
    await NativeLanguage.setPreferredLanguage(languageCode);
  }
}
