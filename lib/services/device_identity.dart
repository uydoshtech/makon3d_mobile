import "dart:math";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Anonymous identifier sent with scan uploads and project sync so data can
/// be grouped per device without any user account.
///
/// Persisted in the iOS Keychain, which survives app deletion — so scans and
/// backed-up projects are restorable after a reinstall. SharedPreferences
/// keeps a mirror copy as a fallback for the rare case the Keychain is
/// unavailable. Installs that predate the Keychain move stored the id only
/// in prefs; the first read migrates that id into the Keychain so existing
/// devices keep their scans and projects.
abstract final class DeviceIdentity {
  static const _prefsKey = "device_id";
  static const _keychainKey = "makon3d_device_id";
  static const _storage = FlutterSecureStorage();
  static String? _cached;

  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    String? keychainId;
    try {
      keychainId = await _storage.read(key: _keychainKey);
      if (keychainId != null && keychainId.isEmpty) keychainId = null;
    } catch (_) {
      keychainId = null; // Keychain unavailable — prefs id still works.
    }

    // Keychain wins: after a reinstall it holds the durable identity while
    // prefs start empty.
    var id = keychainId ?? prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id = _generate();
    }

    if (keychainId != id) {
      try {
        await _storage.write(key: _keychainKey, value: id);
      } catch (_) {
        // Write failed — prefs below still persists the id for this install.
      }
    }
    if (prefs.getString(_prefsKey) != id) {
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
