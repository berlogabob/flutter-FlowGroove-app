# Changelog

All notable changes to FlowGroove are documented here. Versions follow
`MAJOR.MINOR.PATCH+BUILD` (the build number is always strictly increasing for
Play Store `versionCode`).

## 0.37.0+2382 — 2026-11-24

Same app as build 382. The build number jumps so phones that have a test build installed can update to the release.

## 0.37.0+382 — 2026-11-24

Paste a list, a calmer Song Map tempo and review flow, readable fields and text in both themes, and a screen-by-screen check of the app against its design frames.

- Paste a list: add songs from a pasted text list (from a notes app or a chat) to a setlist, the song library or a band's song list. A review step comes first: edit title or artist, remove a row, add a row. A row without an artist matches a library song by title. The band song list has a Menu with Paste a list and Export to CSV.
- Song Map: after Analyze, the tempo question reads "Detected tempo X" with Stretch | Keep, and the review row reads "Sections / N found" with Discard | Done. Other and the BPM chip open the Tempo sheet. The Notes row follows the approved frame. A song's single Intro or Outro is named without a number. Chop splits the section at the play position, Shift + Chop merges the selected pads, and automatic names ("Part E 1") always agree with the letter badge. Play/Pause follows the player, a clip that plays to its end shows Play, the zoom view draws the real waveform on a saved map, and the loop status names the selected pads.
- Readability: field labels sit above the field everywhere; there are no floating labels on the border. Typed text and dropdown values are dark on the white fields in the dark theme. App-bar titles are readable in the light theme. Text buttons use the text colour, not orange; orange is kept for playing, selected and the one main action.
- Layout: every screen, sheet and dialog fits at 360, 393, 412 and 420 dp and at larger text sizes. Fixed clipped or overflowing content in the export-songs, suggestion and import-lyrics dialogs, band chips, the role picker, the fine-tune sheet, the register footer and the song-page auto-scroll bar. The edit-section dialog scrolls with Cancel and Save pinned and shows the Notes counter.
- Other changes: the profile photo menu and the Add-to-band picker use the shared sheet look; the Songs filter sheet, filter chips and the BPM sheet ("Any BPM" hint) follow their frames; the launchpad has dividers between header, pads, tracks and transport; tuner instrument and settings rows show a tap highlight; Home no longer shows the join-a-band sheet to a user with bands when Rehearsals is tapped. Shared links show a new preview image and the title "FlowGroove - shared setlist notebook". A small test APK can be built with `FG_COMPRESS_NATIVE_LIBS=1` and `FLUTTER_BUILD_ARGS="--split-per-abi --target-platform android-arm64"` (about 19 MB). The web build compiles again (backing engine import), and the Cloud Functions dependencies pass the production audit.
- Design system, frames: every app surface has a frame (166 surfaces; 4 system date and time pickers need none). 130 are rendered by a test and compared with their frame, all match and are locked. A render test draws each real screen and compares its structure with the frame, in both themes at four widths and several text sizes (2,080 checks).
- Design system, code: raw size and colour values were replaced by tokens (544 counted values down to 43); the rest are listed with a reason in `design/raw_allow.txt`. New tokens: `spacing.fabClearance` (120), `radius.handle` (2), and the earlier `spacing.mdPlus` (14) and `radius.xsmall` (4). New shared components: `FieldLabel` and `LabeledField`, `AppDropdownField`, `AppBadge.solid`. `CustomTextField` draws its label above the field.
- Design system, guards: the commit hooks and CI check design changes. A change to a frame or `design/figcraft/specs`, `tokens.json` or a locked parity line needs a `Design-Approved:` line in the commit message. Passing frames are locked, metrics and the raw-value allow list only tighten, and new raw values in added lines are rejected. See `design/figcraft/SPEC.md` and `DESIGN_SYSTEM_LINT.md`.

## 0.36.1+381 — 2026-11-21

Fixes from testing 0.36.0 on a Galaxy A24 (420 dp wide).

- Text scales with screen width (up to 1.15x from 360 dp), on top of the Android font size, so wide phones read like the reference phone; Songs filter row, bottom-bar labels and Home tiles fit at the larger size.
- Setlists: fixed BPM column (three digits, tabular) and reserved Spotify slot, so Play, key and BPM line up in every row; key chips scale down instead of wrapping ("Bbm").
- Song Map bars: bar 1 is the first downbeat of the recording, a lead-in shorter than a bar is not counted (Inocente intro: 8 bars, not 9), ruler ticks and numbers sit on the bar lines.
- Song Map pads: two per row on phones with names at full size, as in the approved design.

## 0.36.0+380 — 2026-11-21

Song Map reworked MPC-style after testing 0.35.0 on a phone: one overview, one colour per section, and pads that cut, open and rename sections. Designed in FigCraft first (Song Map page, approved before code).

- One whole-song overview, full width, with the letter lane on the same scale directly under the waveform (the old header waveform and the minimap/breadcrumb are gone). The zoom view below shows only the open section, drawn from the decoded audio, with its parts and bar numbers.
- One letter and one colour per section group on every level (overview, lane, zoom, pads): repeats share them (Chorus 1 and Chorus 2 are both C). Distinct hues; orange is kept for the playing pad.
- MPC keys over the pads: Shift (tap Shift, then a section pad to open its parts; Song goes back), Chop (cut on the nearest bar at the play position, with Undo; Shift + Chop removes the nearest cut) and Range.
- Hold a pad to rename: the sheet offers "Same as" chips, so a section can join an existing group (letter and colour follow).
- An analysis is a visible preview (dashed lane, Discard / Done) and leaving the screen asks to save it, so a new map is no longer lost by accident.
- Phone layout: readable title, two pad rows always visible, Notes folds to one line, pad names and bar counts scale instead of being cut.
- Cleanup: about 1,800 lines of dead code removed, 46 over-deep imports fixed; deploy Makefile and docs match production (landing on FTP, app on Firebase Hosting, flowgroove.app/app/ is a redirect); every lftp call has a network timeout.

## 0.35.0+379 — 2026-11-21

Song Map replaces the pad banks in Song Lab, the brand fonts and theme now render correctly, and the design system is complete in FigCraft. Trace: `docs/plans/song-map/` (UX brief, task ledgers).

- Song Map: one screen with three zoom levels (whole song, section, part). The section lane sits over the waveform, with a minimap and breadcrumb, whole-bar boundary editing (drag, delete, split, one-level undo) and a beat grid at Part level. Pads show the children of the current level.
- Pads: the playing pad is solid orange with a play icon and a progress bar (it was a white outline on a bright colour, hard to see). The queued pad has an orange border and "next". A Range button replaces the two-pad hold. All pads stay visible, and labels show the full name when it fits, else the letter.
- Analyze song replaces the setup wizard. It runs only when tapped; new boundaries are shown for review, and on re-analysis the old map stays until you choose Use new.
- Tempo banner for off-whole tempos: Stretch to the nearest whole BPM (pitch kept) or Keep. Click & drums is disabled while stretched.
- Transport: one row on the theme surface (Play/Pause, Loop, speed, Count-in, Click, Drums).
- Detector: song sections plus 2/4/8-bar parts, a 4/3 meter check, kick downbeat and whole-BPM snap.
- Theme: token pipeline, one orange CTA style, bundled Marcellus and Source Serif 4 (the Roboto fallback is fixed). CustomButton tonal and danger variants, AppBadge and SectionHeader.
- Design system (FigCraft): component states, contrast script and docs page, icons page (the 225 glyphs the app uses), pattern components, prototype links, Song Map components and specs, and `make design-check` (check, verify-components, contrast, offline dry run).

## 0.34.1+378 — 2026-11-14

Audit 2026-11-13 remediation + Flutter 3.50 / Dart 3.14 migration. Trace: `docs/plans/audit-2026-11-13/` (PLAN.md, PROBLEMS.md, TRACE.md).

- Toolchain: Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20 (`compilerOptions`), `sdk: ^3.14.0`, `package:material_ui` imports, `dart fix` sweep, analyzer warnings 84 -> 5.
- UX: 34 audit findings verified on device (Huawei P30), including blank screen after Progress > Continue, Delete in song menus, Title-first Add Song form, tuner dial contrast, per-item accessibility names on list actions, filter/metronome/tag layout overlaps.
- Regressions introduced and fixed before release: list cards not opening (songs, add-song-to-setlist), web build of `backing_engine_web.dart`.
- `record` pinned to 7.1.2 (`record_android` 2.3.0 fails the release build); same-major dependency upgrade reverted.
- Known open: setlist swipe-delete has no confirmation (N-015); Wasm interop warning (M-10); removed-song titles not stored (F-004, F-017); major dependency bumps not attempted.

## Unreleased — verified UX implementation slices (2026-10-24)

- UX-007: create-song FAB tooltip and rendered accessible name; issue remains open for device/TalkBack acceptance.
- NEW-003-I: non-tappable Practice card no longer announces a tap action; tappable Home label and navigation preserved. Seven focused /75 primary related tests passed; device/screen-reader acceptance pending.
- UX-009-I2: shared Home/Practice card distinguishes loading/error from real empty/populated weeks, including accessible status, retained cached refresh data and unchanged navigation. Six focused /74 related primary tests passed; whole PracticeScreen sections and device acceptance remain pending.
- NEW-002-I1: personal Setlists create FAB names its action as Create Setlist; 12 screen tests pass on primary, including rendered semantics and the no-edit FAB guard. Band Setlists also fixed (Create Band Setlist), with 6 primary role/navigation tests and clean analyze. Rehearsals proposal FAB also named (Propose rehearsal), with two focused tests and 68 related primary tests passed. Installed-device/screen-reader acceptance remains pending.
- UX-006: keep the existing backing chooser with active MIDI without replacing the pinned launchpad transport. Portrait/landscape regression verifies opening the chooser, returning to the launchpad and no transport launch; 64 related tests pass on second01.
- No dependency, engine, permission, version or release change. UX-006 device recheck remains blocked, and the publication hold is unchanged.

## Unreleased — systemic UX/UI work plan and publication hold (2026-10-23)

- Added a single activity registry for nine UX findings, existing open GitHub work
  and uncovered verification areas; new problems extend the same scope/history.
- Bounded Ornith 35b / Studio LAN task contracts, dependencies, status and independent
  Hermes acceptance; product UX fixes are not implemented by this planning change.
- Publication/version-bump hold in both Makefiles and the Android release workflow;
  registry/gate regression checks added to development CI. No release or deploy.

## Unreleased — MIDI drum practice + audit round 3 (2026-10-15)

### Drum practice (new)
- **Drums in practice mode.** On the Metronome screen, with a song loaded, a **Drums**
  button opens a sheet: pick a saved drum pattern, press Play, and it follows the
  song's tempo (speed 50/75/100%). **Sync with click** (on by default) starts and
  stops the drums with the metronome, even with the sheet closed. A kit view lights
  up the pad that is playing, with per-lane Mute / Solo.
- **Import a .mid file.** Channel-10 drum notes are read into a 1-4 bar pattern on a
  16th-note grid (the file's own tempo is ignored; the song's tempo is used).
- **Write your own.** "New pattern" opens a step editor (8 steps per page, tap cycles
  Normal / Accent / Ghost / Off) with Play preview and a pinned Save row.
- **Logbook.** Patterns are saved as Song Lab entries (type "Midi") on the song, for
  personal and band songs; band viewers can listen but not save.
- **Real drum sounds.** The nine drum voices are now recorded hits (public-domain "SM Drums" samples, 0.7 MB total); the synthesized sounds remain as a fallback.
- Drums are native-only for now: the button is hidden on web.
- Old app builds show a saved drum pattern as an ordinary note, and re-saving it there
  drops the pattern. Update before editing patterns.

### Fixed / polished (UX audit round 3)
- Selected chips are orange everywhere; empty-state and Drums button states are clearer.
- Importing a file on Android failed silently (lab audio, CSV and .mid import).
- Login shows **Retry** for connection errors.
- Tuning editor and section picker messages no longer render behind their sheet.
- Tuner: note labels no longer touch the dial ticks; long tuning names wrap by word.
- Home quick actions read "Add song / Add band / Add setlist"; song cards show
  "-- BPM" when a song has none; fast tempos (240+) get a "double-time?" hint.
- Android cold start no longer flashes a white starting window.

## Unreleased — analytics instrumentation repair + cloud practice history (2026-08-11)

### Analytics — most of it was never being recorded
- **Screen tracking existed nowhere.** The root `GoRouter` had no navigator
  observer, so `screen_view` fired on exactly two hand-instrumented screens out of
  ~40 (and fired *twice* on each). A `FirebaseAnalyticsObserver` is now registered
  in `createAppRouter`, so every named route reports automatically.
- **Sessions were 30 seconds long.** `AnalyticsService.initialize()` set a 30-minute
  timeout and the debug helper immediately overwrote it with 30 *seconds*. Every
  session-count and engagement-duration figure recorded before this release is
  unreliable. Deleted `lib/utils/analytics_debug.dart`, which also removed a fake
  `analytics_test` event that fired on every release launch.
- **Web was untracked entirely** — analytics initialisation was skipped on web, so
  the `G-DQC026CRM8` stream received nothing. Now initialises on all platforms.
- **The consent switch didn't actually stop anything.** It only gated ~15 of ~55
  events; logins, all tuner events, song/band/setlist events, user properties and
  every Firebase automatic event were transmitted regardless. Consent is now
  enforced at the SDK level via `setAnalyticsCollectionEnabled`, which is the only
  thing that can stop the legacy call sites and the automatic events.
- Wired the events that map to real funnel steps but had never been called —
  signup, logout, song/setlist delete, PDF/CSV export, ChordPro share, member
  removed — at service and repository choke points rather than per screen.
- Removed 24 event methods that had no call sites, and the always-zero
  `song_count` / `setlist_count` user properties.

### Practice history now syncs
- Practice sessions moved from a device-local Hive box to
  `users/{uid}/practiceSessions` in Firestore. Your streak, weekly minutes and
  session logbook now survive a reinstall and appear on a second device; before
  this they were lost with the app. Existing local history is migrated once on
  first launch. The data is private to the account — bandmates never see it.
- Privacy policy, FAQ, Play Data Safety sheet and the delete-account page updated
  to disclose practice data and the correct analytics default (on, opt-out in
  Settings ▸ Privacy).
- Practice and Settings wiki pages can now open in the in-app wiki panel (they
  were missing from the allowlist, so their links escaped to a browser tab).

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
