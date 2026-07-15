# Makon 3D

Standalone iOS app for LiDAR 3D room scanning, extracted from the UyDosh app.
One screen: scan a room with Apple RoomPlan, upload the USDZ to the UyDosh
backend (which also converts it to GLB), then explore the result in the native
SceneKit viewer (3D view, 2D floor plan, dimensions, compass, sun simulation).

- Bundle ID: `com.makon3d.app` (App Store Connect app "Makon 3D")
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
- `lib/services/` — RoomPlan capability check, USDZ bounds/metrics
  (method channel), anonymous upload, native viewer presentation, native
  language sync.
- `lib/l10n/l10n.dart` — map-based en/ru/uz strings + persisted language state.
- `ios/Runner/*.swift` — native stack copied from UyDosh: `RoomScanBoundsPlugin`
  (USDZ footprint metrics), `RoomUsdzViewerViewController` + floor-plan /
  compass / sun-simulation files. Method-channel names keep the `uydosh/`
  prefix so these files stay byte-identical with the UyDosh originals.
- `ios/Podfile` — patches the `flutter_roomplan` pod (UIScene-safe lookups,
  cancel notifications, localized buttons, compass orientation sidecar,
  keep-screen-awake). Same patches as UyDosh; markers kept as `uydosh:`.

## Development

```bash
flutter pub get
flutter run            # requires a physical LiDAR device for actual scanning
flutter analyze && flutter test
```

If you change the Xcode file set, re-run `ruby tool/configure_xcodeproj.rb`
(one-shot script that registered the copied Swift sources, localized strings,
bundle id, and iOS 17.0 deployment target).

## TestFlight / CI

Push an `ios-*` tag to build and upload to TestFlight via GitHub Actions:

```bash
bash tool/release_ios_tag.sh --bump build --commit
```

Or: GitHub → **Actions** → **Release iOS (TestFlight)** → **Run workflow**.

Secrets and first-time profile setup: [`tool/TESTFLIGHT_CI.md`](tool/TESTFLIGHT_CI.md).
