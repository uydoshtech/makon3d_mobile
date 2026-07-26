# Social login setup (Apple / Google / Telegram)

Makon3D reuses UyDosh's login flows against the **shared backend**
(`api.uydosh.com`): Apple and Google go through Firebase and
`POST /users/firebase-auth`; Telegram uses the native Login SDK and
`POST /users/telegram-auth`. Identity is **shared** with UyDosh — signing in
here logs into the same `/users` account.

The Flutter code (under `lib/services/auth/`) is complete, but each provider
needs a one-time **per-app registration** because the UyDosh credentials are
bound to `com.uydosh.app`. Until these steps are done the app runs fine and
the corresponding sign-in buttons are simply hidden.

## 1. Firebase (required for Apple + Google)

1. Firebase console → the existing **UyDosh project** (must be the same
   project — the backend verifies ID tokens against it) → Add app → iOS →
   bundle id `com.makon3d.app`.
2. Download `GoogleService-Info.plist` and add it to `ios/Runner/` in Xcode
   (Runner target, "Copy items if needed").
3. No dart code changes — `FirebaseBootstrap.initialize()` picks up the
   plist automatically and flips the buttons on.

## 2. Sign in with Apple

1. Apple Developer portal → Identifiers → `com.makon3d.app` → enable the
   **Sign In with Apple** capability (Xcode-managed signing usually
   regenerates the profile automatically; the entitlement is already in
   `ios/Runner/Runner.entitlements`).
2. Firebase console → Authentication → Sign-in method → enable **Apple**.

## 3. Google sign-in

1. Firebase console → Authentication → Sign-in method → enable **Google**
   (creates the iOS OAuth client for `com.makon3d.app` automatically).
2. Re-download `GoogleService-Info.plist` if it predates enabling Google.
3. Add the **REVERSED_CLIENT_ID** from that plist as a URL scheme in
   `ios/Runner/Info.plist` (`CFBundleURLTypes` — next to the existing
   `makon3d` scheme entry).

## 4. Telegram (native login)

1. @BotFather → Bot Settings → Login Widget → **Native Login** → register
   the iOS app `com.makon3d.app` with the Apple Developer Team ID
   `D5THR62Q33`. BotFather assigns an App URL:
   `https://app1229616832-login.tg.dev`.
2. Add that host to `ios/Runner/Runner.entitlements` Associated Domains:
   `applinks:app1229616832-login.tg.dev` and
   `webcredentials:app1229616832-login.tg.dev`.
3. Build with:

   ```
   --dart-define=TELEGRAM_NATIVE_REDIRECT_URI_IOS=https://app1229616832-login.tg.dev
   ```

   Makon3D defaults to its `@makon3d_bot` client id (`8923824061`). Pass
   `TELEGRAM_OIDC_CLIENT_ID` only if BotFather issues a replacement client id.

The Telegram button appears automatically once
`TelegramNativeLoginConfig.isConfigured` is true. The browser OAuth
fallback used by UyDosh is **not** wired — the backend redirects to
`uydosh://` and would need a Makon3D variant; native login does not need it.

## Notes

- Session token is stored in the iOS Keychain (`SessionManager`), not
  SharedPreferences, and attached as `Authorization: Bearer` by
  `AuthApi`'s Dio interceptor.
- Scans/projects are still keyed by anonymous `device_id` — logging in does
  not (yet) associate that data with the account.
- App Review: once any third-party login ships, Sign in with Apple is
  mandatory (Guideline 4.8) — ship Apple together with or before Google.
