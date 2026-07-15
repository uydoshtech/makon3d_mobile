import "dart:math";

import "package:shared_preferences/shared_preferences.dart";

/// Anonymous, install-scoped identifier sent with scan uploads so scans can
/// be grouped per device without any user account.
abstract final class DeviceIdentity {
  static const _prefsKey = "device_id";
  static String? _cached;

  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id = _generate();
      await prefs.setString(_prefsKey, id);
    }
    _cached = id;
    return id;
  }

  static String _generate() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, "0")).join();
  }
}
