import Flutter
import UIKit

/// Maps an in-app language code to the iOS `AppleLanguages` preference list.
///
/// Apple's RoomPlan / ARKit frameworks ship a fixed set of localizations
/// (English, Russian, and other majors — but not Uzbek). When `AppleLanguages`
/// is set to a single locale that the framework doesn't translate, iOS falls
/// back to the development region (English) instead of the next-best language
/// the user actually understands. We therefore expand the chosen language into
/// a fallback chain so e.g. an Uzbek user still sees Russian coaching strings
/// inside the native scan UI rather than English.
func makonAppleLanguagesList(for code: String) -> [String] {
  switch code {
  case "uz": return ["uz", "ru", "en"]
  case "ru": return ["ru", "en"]
  default: return [code]
  }
}

/// Registers the `uydosh/room_usdz_viewer` method channel.
/// Channel names are kept identical to the UyDosh app so the shared native
/// viewer stack (RoomUsdzViewerViewController & friends) is used unmodified.
final class RoomUsdzViewerPlugin: NSObject, FlutterPlugin {
  /// Retained for invoking Flutter from the native viewer (room-scan metrics backfill).
  fileprivate static var binaryMessenger: FlutterBinaryMessenger?

  static func register(with registrar: FlutterPluginRegistrar) {
    Self.binaryMessenger = registrar.messenger()
    let channel = FlutterMethodChannel(
      name: "uydosh/room_usdz_viewer",
      binaryMessenger: registrar.messenger()
    )
    let instance = RoomUsdzViewerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "presentLocalFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      let strings = args["strings"] as? [String: String]
    else {
      result(
        FlutterError(
          code: "bad_args",
          message: "Expected {path: String, strings: Map<String,String>}",
          details: call.arguments
        )
      )
      return
    }
    let listingId = (args["listingId"] as? NSNumber)?.intValue ?? 0
    let publishMetricsIfMissing: Bool = {
      if let b = args["publishMetricsIfMissing"] as? Bool { return b }
      if let n = args["publishMetricsIfMissing"] as? NSNumber { return n.boolValue }
      return false
    }()
    let worldPlusXTrueBearingDeg: Double? = {
      if let d = args["worldPlusXBearingDeg"] as? Double { return d }
      if let n = args["worldPlusXBearingDeg"] as? NSNumber { return n.doubleValue }
      return nil
    }()
    let northCorrectionDeg: Double = {
      if let d = args["northCorrectionDeg"] as? Double { return d }
      if let n = args["northCorrectionDeg"] as? NSNumber { return n.doubleValue }
      return 0
    }()
    let isListingOwner: Bool = {
      if let b = args["isListingOwner"] as? Bool { return b }
      if let n = args["isListingOwner"] as? NSNumber { return n.boolValue }
      return false
    }()
    DispatchQueue.main.async {
      RoomUsdzViewerPresenter.present(
        filePath: path,
        strings: strings,
        messenger: Self.binaryMessenger,
        listingId: listingId,
        publishMetricsIfMissing: publishMetricsIfMissing,
        worldPlusXTrueBearingDeg: worldPlusXTrueBearingDeg,
        northCorrectionDeg: northCorrectionDeg,
        isListingOwner: isListingOwner,
        result: result
      )
    }
  }
}

/// Registers the `uydosh/native_language` method channel to allow Flutter to
/// sync the in-app selected language to iOS native UI (e.g. RoomPlan).
final class NativeLanguagePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "uydosh/native_language",
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeLanguagePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setPreferredLanguage" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let code = args["languageCode"] as? String,
      !code.isEmpty
    else {
      result(
        FlutterError(
          code: "bad_args",
          message: "Expected {languageCode: String}",
          details: call.arguments
        )
      )
      return
    }

    // Persisted for the next app launch (the only *guaranteed* way this
    // reaches RoomPlan/ARKit, since those frameworks may have already cached
    // their bundle's localized strings this process); also applied live in
    // case no framework bundle has been touched yet this session.
    UserDefaults.standard.set(makonAppleLanguagesList(for: code), forKey: "AppleLanguages")
    UserDefaults.standard.set(code, forKey: "AppleLocale")
    UserDefaults.standard.synchronize()
    result(true)
  }
}

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
      defaults.set(makonAppleLanguagesList(for: persisted), forKey: "AppleLanguages")
      defaults.set(persisted, forKey: "AppleLocale")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RoomUsdzViewerPlugin") {
      RoomUsdzViewerPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeLanguagePlugin") {
      NativeLanguagePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RoomScanBoundsPlugin") {
      RoomScanBoundsPlugin.register(with: registrar)
    }
  }
}
