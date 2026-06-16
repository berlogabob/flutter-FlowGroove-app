# Unified Avatar System — Design

**Date:** 2026-06-16
**Branch:** second01
**Status:** Approved (design); ready for implementation plan

## Context

This is sub-project **B** of a larger effort (Telegram integration improvements +
profile pictures). It is intentionally self-contained: it only *consumes* the
existing Telegram link data and does not depend on the separate "bot
consolidation" work (sub-project A).

### Problems in the current code

1. **Local-only avatars.** `profile_screen.dart` `_pickPhoto()` saves the picked
   image only to a local file (`profile_photo.jpg` in the app dir) and never
   calls `StorageService`. Avatars do not sync across devices.
2. **Bot-token leak.** The Node bot (`functions/index.js` `/link`) stores the raw
   `https://api.telegram.org/file/bot<TOKEN>/...` URL in the Firestore field
   `telegramPhotoURL`. The bot token is embedded in a user document.
3. **Three competing, inconsistently-persisted sources** (local file, Telegram
   URL, Firebase) juggled via ad-hoc `_photoSource` UI state.
4. **Bands have no avatar at all** — no model field, no storage path, no rules.

### Decisions taken during brainstorming

- External (Telegram/Google) photos are **mirrored into our Storage**, not
  referenced by external URL.
- Band avatars can be set by **admins only** (matches existing band-update rule).
- Image processing is **resize + compress only** (image_picker `maxWidth` /
  `imageQuality`); no crop UI, no new dependency.

## Architecture & Storage Layout

Single source of truth: **Firebase Storage**. The Firestore `photoURL` always
points at our own bucket, never at an external or token-bearing URL.

- `profile_pictures/{uid}.jpg` — user avatar (path + rules already exist)
- `band_avatars/{bandId}.jpg` — **new** band avatar path

Every source (upload / Telegram / Google) resolves to a file in our bucket, so
display is always one stable `photoURL`. `photoSource` (`upload` | `telegram` |
`google`) is kept only as provenance metadata for a UI label.

## Data Model Changes

- **`Band`** (`lib/models/band.dart`): add `photoURL` (`String?`). Regenerate
  `band.g.dart`. Include in `copyWith` with the existing `_sentinel` pattern so
  `null` can be set explicitly (avatar removal).
- **`AppUser`** (`lib/models/user.dart`): add `photoSource` (`String?`) for the
  "Imported from Telegram/Google" label. Already written to Firestore by
  `StorageService`; this just surfaces it in the model.
- **Stop storing the token URL.** The bot's `/link` handler no longer writes
  `telegramPhotoURL`. Telegram photos become on-demand via the callable function
  (below). Legacy `telegramPhotoURL` fields are cleared during migration.

## Services & Data Flow

### `StorageService` (`lib/services/storage_service.dart`) — extend

- `uploadProfilePicture(File)` — **already exists**; wire `profile_screen` to
  actually call it. Confirm it sets `photoSource = 'upload'`. Apply image_picker
  resize/compress at the call site (e.g. `maxWidth: 512`, `imageQuality: 85`).
- `uploadBandAvatar(File file, String bandId)` — **new**. Upload to
  `band_avatars/{bandId}.jpg`, then update the band doc `photoURL` (allowed by
  the existing admin-only band update rule). Throw `ApiError.permission` on
  permission-denied.
- `deleteBandAvatar(String bandId)` — **new**. Delete the file (ignore
  `not-found`) and set `band.photoURL = null`.
- `setAvatarFromGoogle()` — **new**. Read the Google account photo URL from
  `FirebaseAuth.currentUser.photoURL` (public, no token), download the bytes, and
  re-upload via the same `profile_pictures/{uid}.jpg` path with
  `photoSource = 'google'`. Errors if the user has no Google provider/photo.

### New callable Cloud Function `importTelegramAvatar` (`functions/index.js`)

Reuses the existing bot-token secret. Flow:

1. Require auth → `uid` from the callable context.
2. Look up the user doc → `telegramId`. If absent, throw
   `failed-precondition` ("Telegram not linked").
3. `getUserProfilePhotos(telegramId)` → if empty, throw `not-found`
   ("No Telegram photo").
4. `getFile(fileId)` → download bytes server-side using the token.
5. Upload to `profile_pictures/{uid}.jpg` via the Admin SDK.
6. Update the user doc: `photoURL` = clean Storage download URL,
   `photoSource = 'telegram'`, `updatedAt` = server timestamp.
7. Return `{ photoURL }`.

The token never leaves the server and is never persisted to Firestore.

## Security Rules

### Storage (`storage.rules`) — add band path

```
match /band_avatars/{bandId} {
  allow read: if request.auth != null;
  allow write, delete: if request.auth != null &&
    firestore.get(/databases/(default)/documents/bands/$(bandId))
      .data.adminUids.hasAny([request.auth.uid]);
}
```

### Firestore (`firestore.rules`)

No change. Band `photoURL` updates are already covered by the admin-only band
update rule (`isGlobalBandAdmin(bandId)`).

## UI

- **`UserAvatar`** and **`BandAvatar`** reusable widgets (`lib/widgets/`):
  `NetworkImage` from `photoURL`, initials fallback, loading + error states.
  Consolidate the ad-hoc avatar rendering currently scattered across screens.
- **Profile screen** (`lib/screens/profile_screen.dart`): rewrite
  `_showPhotoOptions` →
  - Upload (camera / gallery) → `uploadProfilePicture`
  - Use Telegram photo — enabled when `telegramId != null` → calls
    `importTelegramAvatar`
  - Use Google photo — enabled when google-linked → `setAvatarFromGoogle`
  - Remove → `deleteProfilePicture`

  All paths now persist to Storage; remove the local-file-only branch.
- **Band screen** (`lib/screens/bands/the_band_screen.dart` and/or
  `band_about_screen.dart`): show `BandAvatar` with an edit affordance visible
  only to band admins → upload / remove band avatar.

## Error Handling

- Reuse the existing `ApiError` patterns from `StorageService`.
- Handle: not-linked, no-photo, permission-denied (non-admin band edit), network
  failure/timeout.
- Show a loading state during upload / import; surface failures via the existing
  snackbar pattern.

## Migration

- **Local → Storage** (best-effort, one-time): on profile open, if a local
  `profile_photo.jpg` exists and Firestore has no `photoURL`, upload it via
  `uploadProfilePicture` and delete the local file.
- **Legacy token URLs**: clear the `telegramPhotoURL` field. The
  `importTelegramAvatar` function overwrites `photoURL` with a clean Storage URL
  when the user re-imports.

## Testing

- Unit tests for new `StorageService` methods (`uploadBandAvatar`,
  `deleteBandAvatar`, `setAvatarFromGoogle`) with mocked Storage/Firestore.
- Test for `importTelegramAvatar` with a mocked Telegram client (linked / not
  linked / no-photo paths).
- Widget tests for `UserAvatar` / `BandAvatar` (network success, error fallback,
  initials fallback, loading).
- Follow existing test patterns/structure in `test/`.

## Scope Guard (YAGNI)

Out of scope: crop UI, multi-image galleries, avatar history/versioning, animated
avatars. Just the unified single-avatar flow for users and bands.
