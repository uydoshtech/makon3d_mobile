/// Telegram Login **native SDK** configuration for Makonix.
///
/// The BotFather registration is **per app**: register `com.makon3d.app` in
/// @BotFather → Bot Settings → Login Widget → Native Login, which assigns a
/// Makonix-specific App URL (`https://app1229616832-login.tg.dev`). The
/// UyDosh values cannot be reused — they are bound to `com.uydosh.app`.
///
/// Until that registration exists the iOS redirect URI remains empty,
/// [isConfigured] is false, and the Telegram button is hidden. To enable,
/// build with:
///
/// ```
/// --dart-define=TELEGRAM_NATIVE_REDIRECT_URI_IOS=https://app1229616832-login.tg.dev
/// ```
///
/// and add that host to Runner's Associated Domains (`applinks:` +
/// `webcredentials:`) — see docs/AUTH_SETUP.md.
abstract final class TelegramNativeLoginConfig {
  /// Bot client id from @BotFather (matches backend `TELEGRAM_OIDC_CLIENT_ID`).
  static const clientId = String.fromEnvironment(
    "TELEGRAM_OIDC_CLIENT_ID",
    defaultValue: "8923824061",
  );

  /// iOS native login redirect URI (App URL from BotFather's iOS entry).
  static const redirectUri = String.fromEnvironment(
    "TELEGRAM_NATIVE_REDIRECT_URI_IOS",
    defaultValue: "https://app1229616832-login.tg.dev",
  );

  /// OAuth scopes requested from Telegram (openid is implicit in native SDK).
  static const scopes = ["profile"];

  static bool get isConfigured {
    if (clientId.trim().isEmpty) return false;
    final uri = Uri.tryParse(redirectUri);
    return uri != null && uri.host.isNotEmpty;
  }
}
