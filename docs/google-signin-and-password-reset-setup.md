# Google Sign-In & Password Reset — Setup

Status as of **0.14.0** (June 16, 2026).

| Platform | Firebase config | Status |
|----------|-----------------|--------|
| Android  | real app + `google-services.json` | ✅ Done (debug) |
| Web      | `signInWithPopup` + authorized domains | ✅ Done |
| iOS      | `GoogleService-Info.plist` | ⚠️ Still placeholder |

## Android — DONE (debug)

The Android app is registered and wired up:

- Firebase Android app **`com.flowgroove.app`** =
  `1:703941154390:android:452fa16f90a8ec3d004df7` (project `repsync-app-8685c`).
- `android/app/google-services.json` is the **real** config — `oauth_client` is
  populated (an Android client tied to the debug SHA-1, plus the web client) and
  carries the real project API key.
- `lib/firebase_options.dart` `android` block points at the real app id and the
  matching API key (the mobile fallback key also matches what ships in
  `google-services.json`).
- **Debug** signing certificate fingerprints are registered on the Firebase app:
  - SHA-1  `B4:54:7B:EE:6F:41:82:76:69:19:4B:95:E7:5B:32:56:D4:B3:42:B4`
  - SHA-256 `EA:C6:2D:...:34:7D:AA:1C`
- Auth providers enabled on the project: **Email/Password**, **Google** (and
  Twitter). Verified via the Identity Toolkit Admin API.
- Verified on a physical device: `Firebase.initializeApp()` succeeds and the app
  reaches the auth screen (no "Firebase Initialization Error").

> ⚠️ **Release SHA still pending.** Only the **debug** signing certificate is
> registered. Google Sign-In in a **release / Play App Signing** build will fail
> until the release SHA-1 (and SHA-256) are added to the same Firebase Android
> app. Get the release SHA from your keystore / Play Console (App signing) and
> register it before shipping to the Play Store.
>
> To get the debug SHA again:
> `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

## Web — DONE

The web build signs in via Firebase's `signInWithPopup(GoogleAuthProvider())`
(`lib/providers/auth/auth_provider.dart` → `signInWithGoogle`), so no
`google_sign_in_web` client-id meta tag is needed. Authorized domains already
include `flowgroove.app`, `www.flowgroove.app`, `repsync-app-8685c.web.app`,
`repsync-app-8685c.firebaseapp.com`, `berlogabob.github.io`, and `localhost`.

## iOS — TODO

iOS Firebase is still on placeholder values:

1. Add/confirm an **iOS app** in Firebase Console with bundle id `com.flowgroove.app`.
2. Download the real `GoogleService-Info.plist` and replace
   `ios/Runner/GoogleService-Info.plist`.
3. Copy its `REVERSED_CLIENT_ID` into the URL scheme in `ios/Runner/Info.plist`
   (the `CFBundleURLSchemes` entry — a placeholder is already scaffolded).
4. Update the `ios` block in `lib/firebase_options.dart` with the real iOS app id
   (it currently reuses a placeholder suffix).

## First-login user document

`signInWithGoogle` calls `_ensureUserDocument`, which creates `users/{uid}` with
`accessRole: 'member'` on first Google login. This is required because the
Firestore security rules read `users/{uid}.accessRole` (`isNotDemo`); without the
doc, all writes would be denied.

---

# Password reset

The flow (`forgot_password_screen.dart` → `AppUserNotifier.sendPasswordResetEmail`)
is implemented and verified — Email/Password is enabled and the reset template is
active. If users report "it doesn't work", it is almost always email delivery:

1. **Authentication → Templates → Password reset** — confirm enabled, sender/reply-to valid.
2. **Authentication → Settings → Authorized domains** — action-link domain must be authorized (it is: `repsync-app-8685c.firebaseapp.com`).
3. Check the recipient's **spam** folder. The project currently uses Firebase's
   **default email sender** (no custom SMTP), which is frequently spam-filtered.
   For production, configure a custom SMTP/sender domain.
4. To avoid account enumeration, the app treats `user-not-found` as success and
   always shows a neutral "if an account exists…" message — a missing email will
   *look* successful by design. Verify with a known-good account.
