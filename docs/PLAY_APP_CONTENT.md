# Play Console — App Content answers (#48)

Fill the Play Console forms from this sheet. Every answer must stay in sync with
`site/content/privacy.md` (live at https://flowgroove.app/privacy/).

## Data Safety

| Question | Answer |
|---|---|
| Does your app collect or share user data? | **Yes** (collects; does not share with third parties for their own use) |
| Data encrypted in transit? | Yes (Firebase, HTTPS only) |
| Can users request data deletion? | Yes — in-app (Profile → Delete account) and https://flowgroove.app/delete-account/ |

Collected data types:

| Type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Email address | Yes | No | Account management | Required for sign-in |
| Name (display name) | Yes | No | Account management, app functionality (band member lists) | Optional |
| Photos (avatar) | Yes | No | App functionality | Optional |
| User-generated content (songs, setlists, bands, rehearsals) | Yes | No | App functionality | — |
| User IDs (Firebase UID) | Yes | No | Account management | — |
| App interactions (analytics) | Yes, **only with in-app consent** (Profile → Usage analytics switch, off by default) | No | Analytics | Optional |
| Crash logs / diagnostics | **Not collected** (no Crashlytics in the app) | — | — | — |
| **Audio** | **NOT collected** — microphone audio is processed on-device for tuner pitch detection only; never recorded, stored, or uploaded | No | — | — |
| Location, contacts, financial, health, browsing, files | Not collected | — | — | — |

## Data deletion

- Account creation: **Yes** (email/password, Google)
- In-app deletion path: **Profile → Delete account** (server-authoritative cascade: auth user, songs, setlists, band memberships, avatar)
- Web resource: `https://flowgroove.app/delete-account/`

## App access (reviewer account)

- All features require sign-in. Provide:
  - Email: `reviewer@flowgroove.app`
  - Password: (stored outside the repo — see the Play launch notes; never commit it)
- Instructions for reviewers:
  1. Open the app → "Sign in with email" → credentials above.
  2. The account is pre-seeded with a band ("Review Band"), songs, and a setlist.
  3. Tuner (Home → Tools → Tuner) asks for microphone permission — audio is processed on-device only.

## Content rating questionnaire (IARC)

Music & Audio utility app. Expected answers: violence No, sexuality No, language No,
controlled substances No, gambling No, user-to-user communication **No** (band membership
shares content but there is no chat/messaging), user-generated content visible only to
self-selected band members (invite code/QR), no location sharing, no personal-info sharing
with other users beyond display name/email within a band.

## Target audience

- Age: **13+** (not child-directed). Do not tick any under-13 bracket.

## Ads

- **No ads.**

## Foreground service declaration

- Type: `mediaPlayback` — `MetronomeForegroundService` (`AndroidManifest.xml`), keeps the
  metronome click running with the screen off during practice.
- Video/demo requirement: short screen recording of metronome playing → screen off → still
  playing (record during the #49 screenshot session).

## Permissions summary (for reference)

- `RECORD_AUDIO` — tuner pitch detection, on-device only (matches privacy policy §microphone).
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — metronome.
- `INTERNET` — Firebase.
- No storage, location, camera, or contacts permissions.
