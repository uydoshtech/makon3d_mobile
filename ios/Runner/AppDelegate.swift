import Flutter
import UIKit
import room_scan_kit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Apply the in-app language to `AppleLanguages` BEFORE any framework
    // bundle resolution happens (i.e. before Flutter / RoomPlan / ARKit load).
    // shared_preferences on iOS stores Dart keys in NSUserDefaults under the
    // "flutter." prefix, so we read the same value Dart wrote in
    // `LanguageState.setLanguage`. Without this, RoomPlan's coaching overlay
    // shows in whatever language was cached at process start rather than the
    // currently-selected in-app language.
    let defaults = UserDefaults.standard
    if let persisted = defaults.string(forKey: "flutter.selected_language"), !persisted.isEmpty {
      defaults.set(RoomScanKitAppleLanguages.list(for: persisted), forKey: "AppleLanguages")
      defaults.set(persisted, forKey: "AppleLocale")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
