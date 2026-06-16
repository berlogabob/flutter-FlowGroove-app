# Google Sign-In & Password Reset — Setup

The app code for "Continue with Google" and password reset is implemented, but
both depend on **Firebase Console configuration that must be done manually**.
The committed `GoogleService-Info.plist` / `google-services.json` currently
contain **placeholder** OAuth values (`...abcdefghijklmnopqrstuvwxyz`, empty
`oauth_client`), so Google Sign-In will fail until the steps below are done.

## 1. Enable the Google provider

Firebase Console → **Authentication → Sign-in method** → enable **Google**.
Set the project support email.

## 2. iOS

1. In Firebase Console add/confirm an **iOS app** with bundle id `com.flowgroove.app`.
2. Download the real `GoogleService-Info.plist` and replace
   `ios/Runner/GoogleService-Info.plist`.
3. Copy its `REVERSED_CLIENT_ID` value and paste it into the URL scheme in
   `ios/Runner/Info.plist` (the `CFBundleURLSchemes` entry — a placeholder is
   already scaffolded there).
4. No `GIDClientID` key is required for the credential flow used here, but you
   may add it (`CLIENT_ID` value) if you later adopt the native GIDSignIn UI.

## 3. Android

1. Firebase Console → Project settings → your **Android app** → add the signing
   certificate **SHA-1 and SHA-256** fingerprints (debug and release).
   - Debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
   - Release: see `docs/android-release-signing.md`.
2. Re-download `google-services.json` (the `oauth_client` array will now be
   populated) and replace `android/app/google-services.json`.

## 4. Web

The web build signs in via Firebase's `signInWithPopup(GoogleAuthProvider())`
(see `lib/providers/auth/auth_provider.dart` → `signInWithGoogle`), so no
`google_sign_in_web` client-id meta tag is needed. Just:

1. Firebase Console → Authentication → **Settings → Authorized domains** — add
   the domains the web app is served from (e.g. `flowgroove.app`, `localhost`).

## 5. First-login user document

`signInWithGoogle` calls `_ensureUserDocument`, which creates
`users/{uid}` with `accessRole: 'member'` on first Google login. This is
required because the Firestore security rules read `users/{uid}.accessRole`
(`isNotDemo`); without the doc, all writes would be denied.

---

# Password reset

The flow (`forgot_password_screen.dart` → `AppUserNotifier.sendPasswordResetEmail`)
is correct in code. If users report "it doesn't work", it is almost always
Firebase email configuration:

1. Firebase Console → **Authentication → Templates → Password reset** — confirm
   the template is enabled and the sender/reply-to are valid.
2. **Authentication → Settings → Authorized domains** — the action link domain
   must be authorized.
3. Check the recipient's **spam** folder; Firebase's default sending domain is
   often filtered. For production, configure a custom SMTP/sender domain.
4. To avoid account enumeration, the app now treats `user-not-found` as success
   and always shows a neutral "if an account exists…" message. So a missing
   email will *look* successful by design — verify with a known-good account.
