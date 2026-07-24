import Foundation

/// Central configuration for the App Clip scanning flow.
///
/// NOTE: if the invocation domain ever changes, this file is the only place
/// that needs updating — invocation URL parsing itself is host-agnostic (see
/// `ScanInvocation`) — plus the entitlements and the backend AASA config.
public enum AppClipConfig {
    /// Host that serves the App Clip invocation URLs and the
    /// apple-app-site-association file (see docs/APP_CLIP.md; the backend's
    /// `MAKON3D_SCAN_CLIP_INVOCATION_BASE` must point at this host).
    public static let invocationHost = "scan.makon3d.uydosh.com"

    /// Base URL of the UyDosh backend API used by the App Clip (the backend
    /// serves both products; makon3d endpoints live under /makon3d).
    public static let apiBaseURL = URL(string: "https://api.uydosh.com")!

    /// Telegram bot that hosts the Makon3D Mini App.
    public static let telegramBotUsername = "makon3d_bot"

    /// Short name of the Makon3D Mini App registered in BotFather (/newapp).
    public static let telegramMiniAppShortName = "app"

    /// Builds the invocation URL for a scan session:
    /// `https://scan.makon3d.uydosh.com/s/{scanSessionId}`.
    public static func invocationURL(scanSessionId: String) -> URL {
        URL(string: "https://\(invocationHost)/s/\(scanSessionId)")!
    }

    /// Deep link to the Telegram Mini App without any scan context. Used as
    /// the close-button fallback when the clip was launched without a valid
    /// invocation and there is no session to return to.
    public static var miniAppURL: URL {
        URL(string: "https://t.me/\(telegramBotUsername)/\(telegramMiniAppShortName)")!
    }

    /// Deep link that returns the user to the Makon3D Telegram Mini App after
    /// a scan: `https://t.me/makon3d_bot/app?startapp=scan_{scanSessionId}`.
    ///
    /// Fallback only — the backend's session state carries a `returnUrl`
    /// pointing at whichever Mini App created the session, and
    /// `AppClipRouter` prefers that.
    public static func returnToTelegramURL(scanSessionId: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "t.me"
        components.path = "/\(telegramBotUsername)/\(telegramMiniAppShortName)"
        components.queryItems = [URLQueryItem(name: "startapp", value: "scan_\(scanSessionId)")]
        return components.url!
    }
}
