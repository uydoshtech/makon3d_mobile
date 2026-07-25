import "package:firebase_core/firebase_core.dart";
import "package:flutter/foundation.dart" show debugPrint;

/// Initializes Firebase from the native `GoogleService-Info.plist`.
///
/// The plist is per-app config (Firebase console → add iOS app
/// `com.makon3d.app`) and is not committed until that registration exists,
/// so initialization is allowed to fail: [isReady] stays false and the
/// Apple/Google sign-in buttons are hidden. Telegram login does not use
/// Firebase and works regardless.
abstract final class FirebaseBootstrap {
  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint("Firebase init failed — Apple/Google sign-in disabled: $e");
    }
  }
}
