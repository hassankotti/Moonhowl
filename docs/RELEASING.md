# Releasing Moonhowl

Everything below is done from `apps/mobile`. Version and build number come from
`pubspec.yaml` (`version: X.Y.Z+N`): bump `X.Y.Z` for a user-visible release and
`N` on every store upload (both stores reject a reused build number).

Run `./tool/check.sh` from the repo root before every release.

## One-time setup

### Accounts
- **Apple Developer Program** ($99/year): https://developer.apple.com/programs/enroll/
  Enroll with the Apple ID behind team `H97C79MNR8` (the team already in the Xcode
  project). Enrollment takes 1–2 days.
- **Google Play Console** ($25 once): https://play.google.com/console/signup

### Android upload key (already created, not in git)
- `android/app/upload-keystore.jks` and `android/key.properties` hold the upload key
  and its password. They are git-ignored.
- **Back both files up now** (password manager / encrypted drive). Losing the upload
  key means a support request to Google to reset it; losing it before Play App
  Signing is on means a new app listing.
- Release builds pick them up automatically (see `android/app/build.gradle.kts`).
  Without them, release builds fall back to the debug key so `flutter run --release`
  keeps working on a fresh checkout.

### Privacy policy
Hosted from `docs/` with GitHub Pages:
https://hassankotti.github.io/Moonhowl/privacy.html

## Android (Google Play)

```bash
cd apps/mobile
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`.

In Play Console:
1. Create app → name "Moonhowl" / "عُواء القمر", default language Arabic, Game, free.
2. **Play App Signing:** accept the default (Google manages the app signing key; our
   keystore is the *upload* key).
3. Dashboard → finish the setup tasks: privacy policy URL, app access (no login),
   ads (no), content rating questionnaire, target audience (13+ is simplest; the app
   has user-to-user chat), data safety (no data collected; see
   `docs/store/listing-en.md`), government apps (no), financial features (no).
4. Store listing from `docs/store/listing-ar.md` (default) and `listing-en.md`.
   Assets: icon 512 px (`apps/mobile/assets/icon/android/play-store-icon-512.png`),
   feature graphic 1024×500, at least 2 phone screenshots (16:9 or 9:16, 320–3840 px).
5. Testing → Internal testing → create release → upload the `.aab` → roll out to
   testers. Then Production → create release → review → roll out.

## iOS (App Store)

After enrollment, open `ios/Runner.xcworkspace` once in Xcode, select the Runner
target → Signing & Capabilities, keep "Automatically manage signing" with team
`H97C79MNR8`. Xcode creates the Apple Distribution certificate and the App Store
provisioning profile.

```bash
cd apps/mobile
flutter build ipa --release
```
Output: `build/ios/ipa/moonhowl.ipa` plus `build/ios/archive/Runner.xcarchive`.

Upload either with the Transporter app (drag the `.ipa`) or:
```bash
xcrun altool --upload-app -f build/ios/ipa/moonhowl.ipa -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```
(API keys: App Store Connect → Users and Access → Integrations → App Store Connect API.)

In App Store Connect:
1. My Apps → New App → iOS, name "Moonhowl", primary language Arabic, bundle ID
   `com.hassankotti.moonhowl`, SKU `moonhowl`.
2. App Information: category Games › Board, secondary Games › Family; privacy policy URL.
3. App Privacy: "Data Not Collected".
4. Version page: description/keywords/subtitle from `docs/store/`, screenshots for
   6.9" and 6.5" iPhones (and 13" iPad if iPad is kept enabled), support URL
   (the GitHub repo is fine), age rating questionnaire.
5. Export compliance is already answered in `Info.plist`
   (`ITSAppUsesNonExemptEncryption = false`).
6. Pick the uploaded build, submit for review. First review takes ~1–3 days.

### TestFlight first
Uploaded builds appear in TestFlight within minutes; add yourself as an internal
tester to try the exact store build on your iPhone before submitting.

## Checklist before each store upload
- [ ] `./tool/check.sh` green
- [ ] `version:` bumped in `pubspec.yaml`
- [ ] Played one full game on two real phones on the same Wi-Fi
- [ ] Icons and launch screen look right on both platforms
- [ ] Release notes written (Arabic + English)
