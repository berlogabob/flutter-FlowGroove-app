# Practice Timeline + Backing Sync Implementation Plan

> **SUPERSEDED by `2026-10-22-launchpad-transport.md`** (Dart-side bar-tick restarts cannot be sample-accurate on Android: the click runs in a separate native engine).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Builds on `docs/superpowers/plans/2026-10-21-practice-backing-ux.md` (Tasks 1-2 there are prerequisites: persistent `backingProvider`, single active source).

**Goal:** Load a MIDI backing (e.g. Back to Black) onto a song and practise it against the song's own Intro/Verse/Chorus sections: locked to the click, looping a chosen section, with that section's lyrics and chords on screen.

**Architecture:** The metronome is the only clock. Backing sources are slaves that (re)start on bar-start ticks. `Section.duration` (bars, already stored) gives every section a start bar; a MIDI file is placed on that bar grid by an offset. One "Practice" screen shows the section strip, the playhead, and the current section's chord chart.

**Tech Stack:** Flutter, Riverpod, flutter_soloud, existing `Section.chordChart` + `PerformanceSheetView`/`parseChordProLine`.

**Spec:** none. Source: user report on `AUD_CT1445.mid` (Back to Black) + code read.

## Diagnosis of the reported file (measured with mido)

Format 0, 1 track, ppq 480, one tempo event **483870 µs = 124.0 BPM**, 4/4, 10 channels mixed in one track, **430 notes, 16 bars = 31.1 s**, first note on bar 2 (bar 1 is silent lead-in), no markers/lyrics. The file holds only the first 16 bars of the song (3.9 KB). So "plays only the first part" is partly the file itself. The app currently says nothing about this.

## Why it is out of sync (verified in code)

1. `MidiSongPracticeNotifier` starts on `metronomeProvider.isPlaying` (`midi_song_practice_provider.dart:165`), but the metronome has a count-in (`playbackPhase == countIn`, `metronome_provider.dart:84`). The MIDI starts at the first count-in click, not at bar 1.
2. `start()` re-renders when `_loadedBpm != metronome.bpm` (`:279`). The file is 124 BPM, the song is 123: the first Play renders first, so audio starts seconds late.
3. Tempo is never offered from the file: the user has to guess 124.
4. Voices are played once, not looped (`midi_song_player_soloud.dart` `play` without loop), so after 31 s only the click remains. Drum patterns loop; MIDI songs do not.
5. No clock lock: `Stopwatch` + separate SoLoud voices vs the click engine; drift and device latency are uncorrected (no offset setting for MIDI songs).
6. A song may have 70+ bars; the MIDI has 16. Nothing maps one to the other.

## UX design

- **Practice strip** under the tempo dial on the Metronome screen (and reused in Concert Mode): one block per section, width proportional to `duration` bars, section colour (`colorValue`), bar ruler, moving playhead. Tap a block = jump there; long-press or a Loop chip = loop that section.
- **Now-playing section card** below it: section name, bars, its `chordChart` rendered by the existing chord-over-lyrics view; auto-follows the playhead, tap to pin.
- **Setup on first attach** (one small sheet, three answers, all defaulted): (1) Tempo: "File is 124 BPM, song is 123. Use 124?" (2) Placement: "File is 16 bars. Place at: [Intro] [Verse 1] ..." default = section whose bars best match, else bar 1. (3) When it ends: "Loop it" / "Play once".
- **Visible status** on the card: `MIDI 124 BPM · bars 1-16 · loop` and a warning chip when the file is shorter than the song ("covers 16 of 74 bars").
- **Clear controls**: Play (big button, existing), Loop section, Count-in (existing), Sync nudge ±ms in the mixer.
- Songs with no sections: strip shows a single "Song" block; everything else still works.

## Global Constraints

- Release only from `second01`; web deploy is separate; native only (keep `kIsWeb` guards).
- Inline English strings, MonoPulse tokens, tooltips on icon buttons, inline errors.
- Run `flutter test` yourself, `set -o pipefail`. Codex sandbox cannot run tests.
- Do not change `Section` JSON shape except adding optional fields (old builds overwrite unknown fields; see memory no-authz-data-on-client-written-docs). New placement data lives on `SongLabEntry.midiSong` (already a separate field) not on `Section`.

## Review Focus

- Count-in 0, 1 and 2 bars: MIDI bar 1 lands on the first non-count-in downbeat.
- BPM changed mid-play: no stall; resync at the next bar.
- MIDI with tempo changes or a pickup bar (first note not on a downbeat).
- Song with sections whose `duration` sums to less/more than the MIDI length.
- Zero sections, one section, 40 sections (strip scrolls, no overflow at phone width).
- File with no tempo event (assume 120, say so) and with time signature other than the metronome's.

---

### Task 1: Measure drift and latency (decides Task 4)

**Files:** Create `docs/plans/practice-sync/RESULT.md`; no code.

- [ ] **Step 1:** On A24 and P30, play the Back to Black file with the click, record the speaker with `sox rec` (never ffmpeg avfoundation; see memory tuner-overhaul), measure the offset between click onsets and MIDI drum onsets at loop 1 and after 60 s.
- [ ] **Step 2:** Record offset (ms) and drift (ms/min) per device in `RESULT.md`. Decision rule: drift < 5 ms/min and offset < 20 ms means restart-per-bar (Task 4 option A) is enough; otherwise render the click into the same buffer (option B, separate plan).

### Task 2: Bar-start tick from the metronome

**Files:** Modify `lib/providers/data/metronome_provider.dart`; Test `test/providers/metronome_bar_tick_test.dart`.

**Interfaces:**
- Produces: `final metronomeBarStartProvider = StreamProvider<int>` (emits the 0-based bar index counted from the first non-count-in bar; nothing during count-in) OR a `MetronomeState.barIndex` field if a stream is heavier than the existing `completedBars` handling; pick the one that reuses `completedBars` (`:805`).

- [ ] **Step 1: Tests:** `no emission during 2 count-in bars`; `emits 0 on the first downbeat after count-in`; `emits 1,2,3 on following downbeats`; `stop resets`.
- [ ] **Step 2:** Run `flutter test test/providers/metronome_bar_tick_test.dart` — FAIL.
- [ ] **Step 3:** Implement from the existing tick/`completedBars` logic; no new timer.
- [ ] **Step 4:** Run — PASS. **Step 5:** Commit `feat(metronome): bar-start tick after count-in`.

### Task 3: File facts and placement model

**Files:** Modify `lib/models/midi_song.dart` (add `startBar`, `loop`, `useFileTempo` to `MidiSongMeta`, all optional with defaults 0 / true / false), `lib/services/audio/midi/midi_song_meta_builder.dart`; Test `test/models/midi_song_placement_test.dart`.

**Interfaces:**
- Produces: `MidiSongMeta.startBar: int`, `.loop: bool`, `.useFileTempo: bool`; `MidiSongFacts factsOf(MidiSongData d, {int beatsPerBar})` returning `({double bpm, int bars, int leadInBars, bool hasTempoEvent})`.

- [ ] **Step 1: Tests** using values of the reported file: `bpm == 124.0`, `bars == 16`, `leadInBars == 1`, `hasTempoEvent == true`; JSON round-trip keeps old docs (missing fields default); old-build safety: unknown keys preserved.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement `factsOf` (ticks / (ppq * beatsPerBar)), defaults. **Step 4:** PASS. **Step 5:** Commit.

### Task 4: Slave the MIDI player to bar ticks and loop

**Files:** Modify `lib/providers/data/midi_song_practice_provider.dart`, `lib/services/audio/midi/midi_song_player.dart` (+ `_soloud`, `_web`), `lib/services/audio/midi/midi_track_renderer.dart` (pad every buffer to the same bar-aligned length); Test `test/providers/midi_song_sync_test.dart`.

**Interfaces:**
- Consumes: Task 2 bar tick, Task 3 `startBar/loop`.
- Produces: `MidiSongPlayer.start({int fromBar = 0})`; all track buffers equal length = `bars * barSeconds` exactly (tails folded into the next loop or truncated at the boundary, decided in the test below).

- [ ] **Step 1: Tests (fake player):** `start is called on bar 0 tick, not on isPlaying`; `count-in 2 bars delays start`; `with loop, player restarts every N bars on the bar tick`; `without loop, stops after the last bar and the click continues`; `bpm change re-renders in background while playing and swaps at the next bar tick`; `first Play never waits for a render when facts bpm == loaded bpm`; `all rendered buffers have equal length`.
- [ ] **Step 2:** Run `flutter test test/providers/midi_song_sync_test.dart` — FAIL.
- [ ] **Step 3:** Implement: drop the `isPlaying` start listener for MIDI; start/restart on tick; pre-render at attach time at the effective bpm (file bpm if `useFileTempo`, else metronome bpm) so Play never renders; pad/trim buffers to bar length.
- [ ] **Step 4:** Run, then `flutter test test/midi` — PASS. **Step 5:** Commit.
- Option B (click rendered into the buffer) only if Task 1 says drift is audible.

### Task 5: Setup sheet on attach

**Files:** Create `lib/widgets/midi/midi_placement_sheet.dart`; Modify `lib/widgets/metronome/backing_sheet.dart` (open it on first select, i.e. when `startBar`/`loop` never confirmed); Test `test/widgets/midi_placement_sheet_test.dart`.

**Interfaces:** Consumes `factsOf`, `Song.sections`. Produces `Future<MidiPlacement?> showMidiPlacementSheet(BuildContext, {required MidiSongFacts facts, required double songBpm, required List<Section> sections})`.

- [ ] **Step 1: Tests:** `offers file tempo 124 when songBpm is 123` ("Use 124" default on); `lists sections with start bars and preselects the one that fits 16 bars`; `no sections shows bar 1 only`; `Save writes startBar, loop, useFileTempo via labRepository.saveEntry`; `band viewer sees it read-only`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS. **Step 5:** Commit.

### Task 6: Practice strip + section card

**Files:** Create `lib/widgets/metronome/practice_strip.dart`, `lib/utils/section_timeline.dart`; Modify `lib/screens/metronome_screen.dart`; Tests `test/utils/section_timeline_test.dart`, `test/widgets/practice_strip_test.dart`.

**Interfaces:**
- Produces: `List<({Section section, int startBar, int bars})> buildTimeline(List<Section> sections)`; `int? barOfSection(timeline, sectionId)`; `Section? sectionAtBar(timeline, int bar)`.
- Strip emits `onSeekBar(int)`, `onLoopSection(String? sectionId)`; loop state lives in `backingProvider` (`loopSectionId`).

- [ ] **Step 1: Tests:** timeline sums durations (3+4+4 → starts 0,3,7); `sectionAtBar(6)` is the second block; strip block widths proportional; tap seeks to the block start bar; loop chip toggles; 40 sections scroll horizontally without overflow at 360 dp; section card shows `chordChart` via the existing parser; no sections shows one "Song" block.
- [ ] **Step 2:** FAIL. **Step 3:** Implement; playhead from the Task 2 bar tick plus `currentBeat` for sub-bar motion. **Step 4:** PASS. **Step 5:** Commit.

### Task 7: Seek and section loop in the player

**Files:** Modify `lib/providers/data/backing_provider.dart`, midi + drum providers; Test `test/providers/section_loop_test.dart`.

- [ ] **Step 1: Tests:** `looping section 2 (bars 3-6) restarts MIDI at its offset every 4 bars`; `tap seek during play re-aligns at the next bar tick`; `drum pattern follows the same loop`; `loop cleared on song change`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement `BackingNotifier.seekToBar(int)` and `loopSection(String?)` driving `start(fromBar)` on bar ticks; the metronome itself only counts bars (no seek in the click engine). **Step 4:** PASS. **Step 5:** Commit.

### Task 8: Honest status and warnings

**Files:** Modify `lib/widgets/metronome/backing_card.dart` (from the other plan); Test `test/widgets/backing_card_status_test.dart`.

- [ ] **Step 1: Tests:** shows `MIDI 124 BPM · bars 1-16 · loop`; shows "covers 16 of 74 bars" when shorter than the sections total; shows "No tempo in file, assumed 120" when `hasTempoEvent == false`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS. **Step 5:** Commit.

### Task 9: Device pass and release

- [ ] **Step 1:** `set -o pipefail; flutter analyze lib test 2>&1 | grep error; flutter test 2>&1 | tail -20` — no errors, green.
- [ ] **Step 2:** A24 + P30, install over the existing app: attach `AUD_CT1445.mid` to Back to Black; accept tempo 124; place at Intro; loop; verify first downbeat aligns with count-in 0/1/2; section card follows; loop a 4-bar section; BPM edit mid-play; re-run the Task 1 recording and attach to `RESULT.md`.
- [ ] **Step 3:** From `second01`: `make release LEVEL=minor`, `make deploy-app-hosting`, `make deploy-pages`; confirm `version.json` on both.

## Out of scope

Auto-detecting sections from MIDI markers/lyrics (this file has none; add when a file with markers is at hand); web playback; audio stems; editing the MIDI.

## Self-review

- Coverage: each of the six diagnosed causes maps to a task (1→T4, 2→T3/T4, 3→T3/T5, 4→T4, 5→T1/T4, 6→T5/T6/T8). Sections + lyrics + chords reuse existing fields (T6).
- Types: `startBar/loop/useFileTempo`, `factsOf`, `buildTimeline`, `seekToBar`, `loopSection` used consistently.
- Proportion: signatures, test names and values only.
