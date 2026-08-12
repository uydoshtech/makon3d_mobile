import Flutter
import UIKit
import room_scan_kit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Two-way language sync BEFORE any framework bundle resolution happens
    // (i.e. before Flutter / RoomPlan / ARKit load):
    // - applies the in-app language to `AppleLanguages` so RoomPlan's coaching
    //   overlay follows the in-app language, and
    // - adopts the iOS per-app language (Settings › Apps › Makonix › Language)
    //   into `flutter.selected_language` when the user changed it there.
    // shared_preferences on iOS stores Dart keys in NSUserDefaults under the
    // "flutter." prefix, so the helper reads/writes the same value Dart uses
    // in `LanguageState.setLanguage` / `initialize`.
    RoomScanKitAppleLanguages.syncAtLaunch()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
