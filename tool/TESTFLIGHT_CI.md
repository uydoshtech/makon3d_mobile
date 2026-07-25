# Makon 3D — TestFlight CI

CI builds an App Store IPA and uploads it to TestFlight when you push an
`ios-*` tag (or run the **Release iOS (TestFlight)** workflow).

## Trigger a release

From a clean `main` (or your release branch), after committing what you want to ship:

```bash
# Bump build number, commit+push, create/push ios-<version> tag
bash tool/release_ios_tag.sh --bump build --commit
```

Or from GitHub: **Actions** → **Release iOS (TestFlight)** → **Run workflow** → bump `build`.

That starts **Build & Release iOS TestFlight**, which uploads to App Store Connect.

## Required GitHub secrets

Repo: `uydoshtech/makon3d_mobile` → Settings → Secrets and variables → Actions.

| Secret | What it is |
|--------|------------|
| `IOS_DIST_P12_BASE64` | Base64 of the Apple Distribution `.p12` (same cert as UyDosh / team `D5THR62Q33`) |
| `IOS_DIST_P12_PASSWORD` | Password for that `.p12` |
| `IOS_PROVISION_PROFILE_BASE64` | Base64 of an **App Store** provisioning profile for `com.makon3d.app` (fallback only — when the `ASC_*` secrets are set, CI regenerates this profile via the ASC API each release so new `Runner.entitlements` entries are always covered) |
| `ASC_KEY_ID` | App Store Connect API key id |
| `ASC_ISSUER_ID` | App Store Connect API issuer id |
| `ASC_KEY_P8_BASE64` | Base64 of the API key `.p8` file |

The distribution cert and ASC API key can be the **same values** already used on
`uydosh_mobile`. The provisioning profile must be **new** for Makon 3D.

### Create the Makon 3D App Store profile

1. [developer.apple.com](https://developer.apple.com/account/resources/profiles/list) → **Profiles** → **+**
2. **App Store Connect** (distribution) → Continue
3. App ID: **`com.makon3d.app`** (Real estate 3D scanning)
4. Certificate: your **Apple Distribution** cert (team D5THR62Q33)
5. Name it e.g. `Makon3D AppStore` → Generate → Download

Encode and set the secret:

```bash
base64 -i ~/Downloads/Makon3D_AppStore.mobileprovision | pbcopy
gh secret set IOS_PROVISION_PROFILE_BASE64 -R uydoshtech/makon3d_mobile
# paste when prompted
```

### Copy shared secrets from UyDosh (same team)

You cannot read secret values back from GitHub. Re-set them from your local
copies (same files you used for `uydosh_mobile`):

```bash
REPO=uydoshtech/makon3d_mobile

# Distribution cert (example path — adjust to yours)
base64 -i /path/to/uydosh_distribution.p12 | gh secret set IOS_DIST_P12_BASE64 -R "$REPO"
printf '%s' 'YOUR_P12_PASSWORD' | gh secret set IOS_DIST_P12_PASSWORD -R "$REPO"

# App Store Connect API key
printf '%s' 'YOUR_KEY_ID' | gh secret set ASC_KEY_ID -R "$REPO"
printf '%s' 'YOUR_ISSUER_ID' | gh secret set ASC_ISSUER_ID -R "$REPO"
base64 -i /path/to/AuthKey_XXXXX.p8 | gh secret set ASC_KEY_P8_BASE64 -R "$REPO"
```

## App Store Connect checklist

- App record exists for bundle id `com.makon3d.app` (Makon 3D)
- After the first upload: TestFlight → assign build to a tester group
- Testers need a **LiDAR** device on **iOS 17+**

## Manual upload (without CI)

```bash
flutter build ipa --release
# then deliver build/ios/ipa/*.ipa via Transporter or Xcode Organizer
```
