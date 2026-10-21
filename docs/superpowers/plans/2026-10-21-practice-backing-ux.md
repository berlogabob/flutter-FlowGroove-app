# Practice Backing (drums + MIDI + future instruments) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One coherent "backing" flow on the Metronome screen: pick what plays with the click (drum pattern, MIDI song, later other instruments), see and mix its instruments, and have it keep playing when sheets close.

**Architecture:** A single non-autoDispose `backingProvider` owns the selected source for the active song and keeps the matching player alive. Drum patterns and MIDI songs stay separate engines behind a tiny `BackingSource` description (id, kind, title, tracks); the screen only talks to the provider. Only one source is active at a time.

**Tech Stack:** Flutter, Riverpod (Notifier), flutter_soloud, existing `DrumPracticeNotifier` / `MidiSongPracticeNotifier`.

**Spec:** none. Decisions below come from the 0.27.0 device feedback ("Drums button, inside only drums, no other instruments") and a code read.

## Findings that drive the plan (verified in code)

1. `midiSongPracticeProvider` is `NotifierProvider.autoDispose.family` keyed by `SongLabEntry` (`lib/providers/data/midi_song_practice_provider.dart:359`). It only lives while `MidiSongPanel` is open. Closing the sheet disposes the player, so pressing the big Play button on the Metronome screen plays only the click. This is a functional bug, not just UX.
2. The family key is the whole `SongLabEntry`: any saved edit (mute/volume persist) creates a new notifier and reloads.
3. Drum pattern and MIDI song are independent; both listen to `metronomeProvider.isPlaying`. Loading both double-plays drums (the MIDI file usually has its own drum track).
4. Entry point is split: drums on Metronome, MIDI import and MIDI panel only in Song Lab (hidden on web). A player must leave the metronome to import.

## UX decisions

- **One entry point**: the Metronome "Backing tracks" button (shipped in `db84c922`) becomes a card showing the active source and its instruments.
- **One source at a time**; choosing another stops and unloads the previous. Last choice per song is remembered (SharedPreferences key `backing.<songId>`), restored when the song becomes active.
- **Play is always the big Play button.** Sheets never own playback.
- **Quick mix without opening a sheet**: instrument chips on the card toggle mute (tap) and open the full mixer (long-press or "Mixer" button).
- **Import from the chooser** ("Import MIDI file"), no trip to Song Lab. Hidden on web and for users who cannot edit (existing `canEditProvider` / `canEditBandProvider` gates).
- **Future instruments** = new `BackingKind` value plus an adapter; no screen change.

## Global Constraints

- Release only from `second01`; releasing does not deploy web (run `make deploy-app-hosting` and `make deploy-pages` by hand).
- Native only until a browser test exists: keep `kIsWeb` guards.
- English inline strings, MonoPulse tokens, tooltips on icon buttons.
- Errors render inline (snackbars render behind sheets).
- Codex runs tests poorly in its sandbox: run `flutter test` yourself with `set -o pipefail`.

## Review Focus

- Song changes while a source plays: playback stops, state clears, no stale card.
- Drum pattern selected, then a MIDI song with a drum track: only one source is audible.
- Role-less / zero-track MIDI song: chooser row still opens, card shows "No instruments".
- Band viewer: sees and plays sources, no import or edit controls.
- Offline: chooser and card render from cache, no spinner loop.

---

### Task 1: Keep MIDI playback alive outside the sheet (bug fix)

**Files:**
- Create: `lib/providers/data/backing_provider.dart`
- Modify: `lib/providers/data/midi_song_practice_provider.dart:359`, `lib/widgets/midi/midi_song_panel.dart`
- Test: `test/providers/backing_provider_test.dart`

**Interfaces:**
- Produces: `enum BackingKind { drums, midiSong }`; `class BackingSelection { BackingKind kind; String entryId; String songId; String? bandId; }`; `final backingProvider = NotifierProvider<BackingNotifier, BackingSelection?>`; `BackingNotifier.select(SongLabEntry entry, {String? bandId})`, `clear()`.
- Change `midiSongPracticeProvider` family key from `SongLabEntry` to `String entryId` only if the notifier can read the entry from `backingProvider`; otherwise keep the key and have `BackingNotifier` hold `ref.listen(midiSongPracticeProvider(entry), (_, _) {})` for the selection's lifetime so it is never disposed.

- [ ] **Step 1: Write failing test** `selected MIDI source survives panel close`: override `midiSongPlayerProvider` with a fake that records `start`; `select(midiEntry)`, mount then unmount `MidiSongPanel`, `metronomeProvider.notifier.toggle()`; assert fake `start` called once.
- [ ] **Step 2: Run** `set -o pipefail; flutter test test/providers/backing_provider_test.dart` — expect FAIL (player disposed).
- [ ] **Step 3: Implement** `BackingNotifier` holding the keep-alive listen described above; `MidiSongPanel` calls `backing.select(entry)` on open instead of relying on its own lifetime.
- [ ] **Step 4: Run** same command — expect PASS; then `flutter test test/midi` — expect all pass.
- [ ] **Step 5: Commit** `fix(midi): keep MIDI song playing after the sheet closes`.

### Task 2: Single active source and per-song memory

**Files:**
- Modify: `lib/providers/data/backing_provider.dart`, `lib/providers/data/drum_practice_provider.dart` (expose `clearPattern()` already exists; confirm it stops)
- Test: `test/providers/backing_provider_test.dart`

**Interfaces:**
- Consumes: Task 1 `BackingNotifier`.
- Produces: `BackingNotifier.select` stops the previous source (`DrumPracticeNotifier.clearPattern()` or MIDI `stop()` + dispose of its keep-alive); `restoreFor(String songId, List<SongLabEntry> entries)` picks the stored entry id or, if exactly one source exists, that one.

- [ ] **Step 1: Tests**: `selecting MIDI clears the drum pattern`; `selecting drums releases the MIDI keep-alive`; `song change clears selection`; `restoreFor picks remembered id`; `restoreFor with one source auto-selects`; `restoreFor with two and no memory selects nothing`.
- [ ] **Step 2: Run** `flutter test test/providers/backing_provider_test.dart` — FAIL.
- [ ] **Step 3: Implement** the three methods; persist id under `backing.<songId>` via the existing prefs provider; listen to `metronomeProvider.select((s) => s.activeSong?.id)` and call `clear()` then `restoreFor` when it changes.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(backing): single active source with per-song memory`.

### Task 3: Backing card on the Metronome screen

**Files:**
- Create: `lib/widgets/metronome/backing_card.dart`
- Modify: `lib/screens/metronome_screen.dart` (`_MetronomeSongLibrary`, replaces the "Backing tracks" button), `lib/providers/data/drum_active_provider.dart` (keep; card reads it for drum label)
- Test: `test/widgets/backing_card_test.dart`

**Interfaces:**
- Consumes: `backingProvider`, `midiSongPracticeProvider(entry)` state (`tracks`, `soloed`, `setMute(i, mute:)`), `labEntriesProvider((songId, bandId))`.
- Produces: `class BackingCard extends ConsumerWidget`; tooltip `'Backing tracks'` stays on the idle state so existing tests keep working.

- [ ] **Step 1: Tests**: `idle card shows 'Backing tracks' and opens BackingSheet`; `MIDI selected shows one chip per track with role name`; `tapping a chip toggles mute`; `no active song shows 'Pick a song first'`; `drum pattern selected shows pattern name and no chips`.
- [ ] **Step 2: Run** `flutter test test/widgets/backing_card_test.dart` — FAIL.
- [ ] **Step 3: Implement** `BackingCard` (Outlined idle, Filled active like today). Chips are `FilterChip` with `Tooltip`; long-press opens `MidiSongPanel`.
- [ ] **Step 4: Run** the new test plus `flutter test test/midi` — PASS.
- [ ] **Step 5: Commit** `feat(metronome): backing card with instrument chips`.

### Task 4: Chooser with import

**Files:**
- Modify: `lib/widgets/metronome/backing_sheet.dart`, `lib/screens/songs/midi_import_screen.dart` (accept a return value)
- Test: `test/widgets/backing_sheet_test.dart`

**Interfaces:**
- Consumes: existing import screen entry used by `song_lab_screen.dart` (read its route/constructor first), `backingProvider.select`.
- Produces: rows call `backing.select(entry)` and close the sheet; footer row `Import MIDI file` shown only when `!kIsWeb` and `canEditProvider`/`canEditBandProvider(bandId)`.

- [ ] **Step 1: Tests**: `import row hidden for band viewer`; `import row hidden on web`; `picking a MIDI row selects it and pops`; `new import auto-selects the created entry`.
- [ ] **Step 2: Run** `flutter test test/widgets/backing_sheet_test.dart` — FAIL.
- [ ] **Step 3: Implement** per Interfaces; the import screen pops with the new `SongLabEntry` so the chooser selects it.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(backing): import MIDI from the chooser`.

### Task 5: Mixer sheet stops owning playback

**Files:**
- Modify: `lib/widgets/midi/midi_song_panel.dart`, `lib/widgets/metronome/drum_practice_panel.dart`
- Test: `test/midi/midi_song_panel_test.dart` (extend)

- [ ] **Step 1: Test**: `panel Play button toggles metronome and panel close leaves it playing`.
- [ ] **Step 2: Run** `flutter test test/midi/midi_song_panel_test.dart` — FAIL.
- [ ] **Step 3: Implement**: rename the panel's header to "Mixer"; keep per-track mute/solo/volume; remove any dispose-time `stop()`; no behavior added.
- [ ] **Step 4: Run** `flutter test test/midi` — PASS.
- [ ] **Step 5: Commit** `refactor(midi): panel is a mixer, playback is owned by backing`.

### Task 6: Verify, device pass, release

- [ ] **Step 1:** `set -o pipefail; flutter analyze lib test 2>&1 | grep -E "error" ; flutter test 2>&1 | tail -20` — no errors, suite green.
- [ ] **Step 2: Device pass (A24 + P30, install over existing build, do not uninstall)**: import a multi-track `.mid` from the chooser; Play from the big button; close the mixer, still playing; mute a chip; switch to a drum pattern, only drums audible; change song, card resets; band viewer has no import row; airplane mode still shows the card. Record findings in `docs/plans/ux-remediation/` style notes.
- [ ] **Step 3:** from `second01`: `make release LEVEL=patch`, then `make deploy-app-hosting` and `make deploy-pages`; confirm `version.json` on both hosts.
- [ ] **Step 4: Commit** any audit notes.

## Out of scope (follow-ups)

Web playback; Concert Mode showing the card (it already follows Play, add the card after device feedback on sound quality); audio-stem and chord/bass-generator sources (new `BackingKind` + adapter); replacing the generated-tone synth.

## Self-review

- Coverage: bug (Task 1), single source (2), entry point and mixing (3, 5), import flow (4), verification and release (6). Findings 1-4 each map to a task.
- Types: `BackingKind`, `BackingSelection`, `backingProvider`, `select/clear/restoreFor` used identically in Tasks 1-4.
- Proportion: five code tasks, signatures and test names only.
