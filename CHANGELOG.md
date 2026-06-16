# Changelog

All notable changes to FlowGroove are documented here. Versions follow
`MAJOR.MINOR.PATCH+BUILD` (the build number is always strictly increasing for
Play Store `versionCode`).

## 0.14.0+203 — 2026-06-16

Freeze release: the first build with a fully working, on-device-verified Firebase
Android configuration.

### Firebase / Auth
- Registered the real Firebase **Android app** `com.flowgroove.app`
  (`1:703941154390:android:452fa16f90a8ec3d004df7`) and shipped the real
  `android/app/google-services.json` (populated `oauth_client`, real API key),
  replacing the previous placeholder that caused the "Firebase Initialization
  Error" screen.
- Synced the `android` block in `lib/firebase_options.dart` (real app id + API key).
- Registered the **debug** signing SHA-1/SHA-256 on the Firebase app.
- Confirmed **Email/Password** and **Google** sign-in providers are enabled.
- Verified `Firebase.initializeApp()` succeeds on a physical Android device.
- Documented and verified the **password reset** flow.

### Bands / data
- Server-authoritative band membership via Cloud Functions
  (`functions/src/bands.js`, `lib/services/band_function_service.dart`), with a
  `scripts/backfill_band_member_uids.js` migration.
- Song tagging support (`lib/utils/song_tags.dart`) and song form updates.
- Firestore security rules updates.

### Docs
- Rewrote `docs/google-signin-and-password-reset-setup.md` to reflect the
  completed Android setup and remaining iOS / release-SHA work.
- Bumped version references in `README.md`, `ARCHITECTURE.md`,
  `DEPLOYMENT_GUIDE.md`.

### Known gaps
- **Release / Play App Signing SHA-1 not yet registered** — Google Sign-In will
  fail in a Play release until it is added.
- **iOS Firebase still on placeholder config** (`GoogleService-Info.plist`,
  placeholder iOS app id).
- Release artifacts are **debug-signed** (no `android/key.properties` present);
  add a release keystore before a Play upload.
