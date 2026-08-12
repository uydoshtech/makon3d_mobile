# Makonix

## Project persistence

Authenticated projects are cached transactionally in
`Application Support/makon_projects.sqlite3`, partitioned by account. The
backend project API remains the durable cross-device copy. An empty local
database triggers a server restore and is never interpreted as a remote
deletion.

Older releases stored the complete project list as JSON in
`SharedPreferences`. On first launch after upgrading, that JSON is imported
into SQLite in one transaction and removed only after the import succeeds.
`SharedPreferences` remains in use for lightweight settings and migration
markers, not project records.

Standalone iOS app for LiDAR 3D room scanning, extracted from the UyDosh app.
One screen: scan a room with Apple RoomPlan, upload the USDZ to the UyDosh
backend (which also converts it to GLB), then explore the result in the native
SceneKit viewer (3D view, 2D floor plan, dimensions, compass, sun simulation).

- Bundle ID: `com.makon3d.app` (App Store Connect app "Makonix")
- iOS 17+, LiDAR-capable iPhone/iPad only
- Languages: Uzbek, Russian, English

## Backend

Uses the shared `uydosh_backend` API (default `https://api.uydosh.com`,
override with `--dart-define=API_BASE_PATH=...`).

- `POST /makon3d/scans` — anonymous upload: `{ usdzData (base64), device_id, room_scan_metrics? }`
  → `{ id, usdzUrl, glbUrl }`. Stored in the `makon3d_scans` table and under
  `public/images/makon3d/{id}/` on the server.
- `GET /makon3d/scans/:id`, `GET /makon3d/scans?device_id=...` — read back.

No login: uploads are keyed by an install-scoped random `device_id`
(`lib/services/device_identity.dart`).

## Architecture

- `lib/screens/scan_screen.dart` — the single screen (capture → upload → viewer).
- `lib/services/` — RoomPlan capability check, anonymous upload, and thin
  wrappers around [`room_scan_kit`](https://github.com/uydoshtech/room_scan_kit)
  (viewer, bounds, native language).
- `lib/l10n/l10n.dart` — map-based en/ru/uz strings + persisted language state.
- Native SceneKit viewer / editable floor plan live in **`room_scan_kit`**
  (private Flutter plugin), not in `ios/Runner`.
- `ios/Podfile` — patches the `flutter_roomplan` pod (UIScene-safe lookups,
  cancel notifications, localized buttons, compass orientation sidecar,
  keep-screen-awake). Markers kept as `uydosh:`.

## Development

```bash
flutter pub get
flutter run            # requires a physical LiDAR device for actual scanning
flutter analyze && flutter test
```

`room_scan_kit` is a private git dependency (`ref: v0.1.0`). Local `pub get`
needs GitHub auth that can read `uydoshtech/room_scan_kit`. CI uses the
`ROOM_SCAN_KIT_GITHUB_TOKEN` repo secret (classic PAT or fine-grained token
with Contents: Read on that repo).

`ruby tool/configure_xcodeproj.rb` only maintains Localizable/InfoPlist strings
and bundle id / iOS 17 deployment target — not the viewer Swift sources.

## TestFlight / CI

Push an `ios-*` tag to build and upload to TestFlight via GitHub Actions:

```bash
bash tool/release_ios_tag.sh --bump build --commit
```

Or: GitHub → **Actions** → **Release iOS (TestFlight)** → **Run workflow**.

Secrets and first-time profile setup: [`tool/TESTFLIGHT_CI.md`](tool/TESTFLIGHT_CI.md).
