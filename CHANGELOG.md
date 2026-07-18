# Changelog

All notable changes to FlowGroove are documented here. Versions follow
`MAJOR.MINOR.PATCH+BUILD` (the build number is always strictly increasing for
Play Store `versionCode`).

## Unreleased — UX audit remediation + setlist/navigation fixes (2026-07-19)

Branch `fix/ux-audit-2026-07` (PR #174 → `second01`). On-device verified on a real
Android device.

### UX/UI audit (Android) — 21 findings
- **Accessibility:** stopped duplicated nav/app-bar Semantics labels app-wide
  (`Home\nHome` → `Home`) by excluding the child text; labelled the tuner
  note-ring tap targets and other icon-only controls.
- **Design tokens (MonoPulse):** black-on-orange FABs/play glyphs per the token
  (~6.5:1 vs ~3:1); on-palette chips + pills instead of the Material
  `secondaryContainer` grey; neutral Home tile labels with the accent on the
  icon only; brighter tuner note-ring.
- **Navigation:** Rehearsals opens a titled "choose a band" picker / empty-state
  instead of dumping on the Bands list; the Menu sheet titles itself "Menu";
  brighter Back/Menu; every tool footer shows a Menu.
- **Metronome:** ≥48 dp beat-toggle tap targets; symmetric ±5/±1 steppers
  (orange reserved for Play).
- **Lists:** FAB no longer covers the last card; Band cards gained an overflow
  menu; song-card action icon distinguished from the BPM badge; filter-chip row
  fades to signal it scrolls.
- **Practice:** pending/overdue homework icon (not a "done" check); sub-minute
  sessions show real seconds instead of "0 min".

### Navigation / shell
- Removed the duplicate "Edit Song" bottom bar: full-screen editors (performance
  sheet, song editor, Event Kit, song-merge) push on the **root navigator** so
  the shell's bar can't stack under theirs.
- Fixed the stuck pushed-mode bar over Home after **logout → login**
  (`BranchStackObserver` reset its leaked page-count on branch-root re-mount).
- Band setlist detail uses a new **`band-setlist-view`** route under the bands
  branch, so songs resolve against the band library and the bar shows the
  setlist's name (not the list title), keeping you in the Bands tab.

### Setlists
- Band setlist songs resolve again (the view was dropping `bandId`); the personal
  list hides band-typed setlists.
- Event Kit moved from the detail's bottom card to the setlist card's 3-dot, with
  an at-a-glance "kit set up" badge; opens full-screen.
- Setlist cards now show **one configurable pinned quick-action icon + overflow**
  (mirrors song cards): `setlistQuickActionProvider`, a Settings tile "Quick
  action on setlist cards" (default *Open in metronome*), and "Edit setlist" in
  the card + band-screen menus. Dropped the standalone edit pencil.
- Setlist editor: removed the drag handle (reorder by long-press) and the
  per-song tuner/metronome buttons so song names are readable.

### Data
- Deleted a stray band-shaped setlist document mis-saved into a user's personal
  collection (from the now-fixed Event-Kit save path).

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
