# Android Release Build, Signing & GitHub Release

How the Android APK is built, signed, and published, and what you need to set up
for a properly-signed release.

## Pipeline overview

`.github/workflows/pages-android.yml` runs on pushes to `main` / `master` /
`second01`, on `v*` tags, and via manual dispatch:

1. Sets up Java 17, Flutter (stable) and Hugo.
2. `flutter pub get`.
3. Builds the Hugo site + Flutter web into `docs/`.
4. **Create `.env` from secrets** — writes runtime config from GitHub Secrets
   (Firebase / Spotify / Twitter). Missing secrets are written empty and treated
   as "not configured"; the Firebase key falls back to the public project key so
   the build never hard-fails.
5. **Configure release signing** — if `ANDROID_KEYSTORE_BASE64` is set, decodes
   the keystore and writes `android/key.properties`. If not set, the build falls
   back to debug signing.
6. `make build-android` → `scripts/build-mobile-with-env.sh apk` →
   `flutter build apk --release` (config injected via `--dart-define`).
7. Uploads the APK as a workflow artifact.
8. On **branch / manual** runs, deploys GitHub Pages (skipped on tag runs to
   avoid a duplicate deploy).
9. On **`v*` tag** runs, creates/uploads the APK to the matching GitHub Release.

Local equivalent: `make build-android`, `make build-appbundle`, or `make release`
(builds APK + AAB, bumps version, tags, pushes, and creates the GitHub Release).

## Signing model

`android/app/build.gradle.kts` signs the release build with the real key when
`android/key.properties` is present, and otherwise falls back to the **debug**
key. Debug-signed APKs install fine for sideloading but are **not** acceptable
for the Play Store and use a shared, well-known key — set up real signing before
public distribution.

`key.properties`, `*.keystore` and `*.jks` are gitignored and must never be
committed.

## One-time setup for signed releases

### 1. Generate an upload keystore

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Keep this file and its passwords safe and backed up — losing it means you can no
longer ship updates under the same signing identity (unless you use Play App
Signing).

### 2. Add GitHub repository secrets

Settings → Secrets and variables → Actions → New repository secret:

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of the keystore: `base64 -i upload-keystore.jks \| pbcopy` (macOS) or `base64 -w0 upload-keystore.jks` (Linux) |
| `ANDROID_KEYSTORE_PASSWORD` | keystore (store) password |
| `ANDROID_KEY_ALIAS` | key alias, e.g. `upload` |
| `ANDROID_KEY_PASSWORD` | key password |

Optional app-config secrets (only needed if you want these features enabled in
the released APK — otherwise they stay disabled):

| Secret | Purpose |
| --- | --- |
| `FIREBASE_API_KEY` | overrides the public fallback key |
| `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`, `SPOTIFY_PROXY_URL` | Spotify integration |
| `TWITTER_API_KEY`, `TWITTER_API_SECRET` | Twitter/X integration |
| `TELEGRAM_BOT_TOKEN` | Telegram features |

### 3. Local signed build (optional)

Create `android/key.properties` (gitignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=********
keyAlias=upload
keyPassword=********
```

Then `make build-android` or `make build-appbundle` produces a signed artifact.

## Notes

- The Firebase API key is **not a secret** — it already ships in
  `android/app/google-services.json` and `assets/env.demo.json`. Security is
  enforced by Firestore Rules + App Check, not by hiding the key.
- For Play Store distribution, prefer **Play App Signing**: upload the AAB signed
  with your upload key; Google manages the final app-signing key.
