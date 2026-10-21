# Launchpad Transport (one clock, sections as pads) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. **Supersedes** `2026-10-22-practice-timeline-and-sync.md` (its sync approach, "restart on bar ticks from Dart", cannot be sample-accurate on Android; see Findings). Keeps `2026-10-21-practice-backing-ux.md` Tasks 1-2 (persistent single active source) as prerequisites.

**Goal:** For practice and learning, the click, drums, every MIDI instrument and the on-screen section/lyrics/chords are always locked to one clock, and song sections behave like launchable pads (queued, quantized to the bar, loopable).

**Architecture:** Each platform's audio engine gets one `BackingMixer` that mixes pre-rendered instrument stems into the SAME PCM stream as the click, positioned by that engine's own absolute frame counter. Dart never starts, stops or loops audio by timer; it sends bar-based commands that the engine applies on a frame-exact quantize boundary. Pads, playhead and lyrics are driven by engine events.

**Tech Stack:** Kotlin `AudioTrack` engine (Android, `MetronomeEngine.kt`), Dart `MetronomeScheduler` + `NativeSoLoudSink` (iOS/other native), Flutter/Riverpod UI, existing MIDI renderers.

**Spec:** none; sources are the user's requirements ("always in sync", "Launchpad", building blocks behave alike) and the code read below.

## Findings (verified in code)

1. **Two engines, two clocks on Android.** The click runs in the native foreground service: its own render thread writing a Kotlin `AudioTrack` in 20 ms chunks (`MetronomeEngine.kt:312-410`, selected by `useNativeAndroidPlayback`, `metronome_runtime_providers.dart:1030`). MIDI and drums play through `flutter_soloud` voices in Dart. Different device streams, latency, and clocks: sample-lock between them is impossible, so "off sync" is structural. iOS uses the Dart unified engine (`MetronomeScheduler`), also not shared with SoLoud voices.
2. The click is a pure function of an absolute frame index (`PcmClickRenderer.renderChunk(startFrame)`, Kotlin mirror `ClickRenderer`). A tempo `update` restarts the grid (`epochFrame = framesWritten`). Adding sources into the same render loop is natural and keeps the foreground-service robustness (screen off, calls).
3. The click interval is fractional frames (`Math.round(j * intervalFrames)`). Anything musical must re-anchor to this grid every bar or sub-frame rounding accumulates.
4. `Section.duration` is "1-4 phrases" (visual weight, default 2, `song_constructor.dart:90,162`), NOT bars. Sections have no reliable bar length.
5. Old app builds rewrite whole docs and drop unknown fields (memory: no-authz-data-on-client-written-docs). New arrangement data must not live on `Song`/`Section`; it lives on the backing's own doc `SongLabEntry.midiSong` (already isolated from old builds).
6. The user's file (`AUD_CT1445.mid`): 124.0 BPM, 4/4, 16 bars, bar 1 silent, no markers.

## The sync contract (each line gets a test)

- **C1** One clock: every audible event derives from the engine's absolute frame counter. No `Timer`, `Stopwatch` or `SoLoud.play` start for anything musical.
- **C2** Commands carry bars, never seconds. Launch, stop, loop, seek, tempo swap apply only at a quantize boundary computed in frames (default: next bar), with lookahead >= one chunk.
- **C3** Re-anchor every bar: backing bar k starts at the click grid's bar-k frame, so drift cannot exceed 1 frame at any length.
- **C4** Backing is audible only if `stem.renderBpm == engine bpm` and `beatsPerBar` match. A tempo change makes backing silent (pad shows "Rendering 124 BPM") until the new render is swapped in on a bar line. Out-of-sync audio can never play.
- **C5** One latency offset (`latencyOffsetFrames`) applies to click and backing identically.
- **C6** The click never restarts on a launch or jump. Jumps change only which backing bar plays and which section is shown.
- **C7** UI position comes from engine events (bar started, token state), not a UI timer.

## Launchpad UX

- **Pads** = one per section, in song order, wrapping grid (2-3 columns at phone width), big touch targets. Each shows name, bars, colour, and a state that is never colour-only: idle / queued (pulsing outline + "Next bar") / playing (filled + bar progress + loop icon).
- **Tap a pad** while stopped: count-in, then that section from its first bar. While playing: becomes queued, switches on the next bar line (setting: Bar or End of section). Current section keeps looping until then.
- **Section end**: Loop (default for practice) or Play through to the next pad. One global chip, plus a per-pad long-press "Loop only this".
- **Transport row**: Play/Stop (Stop = now, long-press = end of bar), tempo with Speed % (50-120, renders slower backing, no pitch change), count-in, quantize chip.
- **Instrument strip** (below pads): Click, Drums, Bass, Keys, Guitar, Lead (role groups from role detection): Mute, Solo, and "I play this" = mute my part (minus-one). Volume in the long-press mixer.
- **Section card**: lyrics + chords of the playing section (existing `chordChart` renderer), pinned to the queued section while queued; swipe to peek other sections without launching.
- **Honest status line**: `MIDI 124 BPM · 16 bars · covers Intro, Verse 1` and warnings ("File shorter than song", "Rendering for 123 BPM").
- Song without a map: one pad "Song" (whole backing), sections still shown as text.

## Data model

`MidiSongMeta` (on the lab entry, not on `Song`) gains optional fields, defaults keep old docs valid:
`startBar: int = 0`, `sectionMap: List<SectionSpan> = []` where `SectionSpan { sectionId: String, startBar: int, bars: int }`, `useFileTempo: bool = false`, `endBehavior: 'loop'|'next'|'stop'`.
First attach opens a one-time setup sheet: tempo (use 124? / keep 123), where the file starts, which sections it covers and how many bars each (prefilled by dividing the file's bars across sections, editable). SMF markers (meta 0x06/0x07) prefill names when a file has them.

## Global Constraints

- Release only from `second01`; web deploy separate; Android release signing note: install over existing app, never uninstall P30/A24.
- Native only; keep `kIsWeb` guards (web has its own AudioContext lookahead engine; same contract later).
- Inline English strings, MonoPulse tokens, tooltips, inline errors.
- Run `flutter test` yourself with `set -o pipefail`; Codex sandbox cannot run tests or Gradle.
- The Kotlin and Dart mixers share one JSON golden-vector file; a change to either must keep both green.

## Review Focus

- BPM changed during play, including `update` restarting the click grid: backing mutes until re-rendered, resumes on a bar line, never early.
- Count-in 0/1/2 with jump queued during count-in.
- Audio route change (Bluetooth) mid-play: engine recovery keeps backing aligned (frame counter continuity).
- Memory: 4-minute song, 6 stems at the device rate.
- Screen off / app backgrounded: playback and launches keep working (native thread owns timing).
- Sections not covered by the map, overlapping spans, zero sections.
- Time signatures other than 4/4 (file vs metronome).

---

## Phase 0: Spike and decisions (go/no-go before any UI)

### Task 1: Prove frame-exact mixing in the Kotlin render loop

**Files:** Create `android/app/src/main/kotlin/com/flowgroove/app/BackingMixer.kt` (pure Kotlin, no Android imports), `android/app/src/test/kotlin/com/flowgroove/app/BackingMixerTest.kt`, `test/fixtures/backing_golden.json`; Modify `android/app/build.gradle(.kts)` (`testImplementation "junit:junit:4.13.2"`).

**Interfaces:**
- Produces: `class BackingMixer(sampleRate: Int)` with `load(stems: List<ShortArray>, renderBpm: Double, beatsPerBar: Int)`, `command(c: BackingCommand, nowFrame: Long, barFrame: (Long) -> Long)`, `mix(out: DoubleArray, chunkStart: Long, engineBpm: Double)`; `data class BackingCommand(val token: Int, val kind: Kind, val fromBar: Int, val toBar: Int, val loop: Boolean, val quantize: Quantize)`.

- [ ] **Step 1: Write failing golden test**: for bpm 123 / rate 48000 / 4 beats, an impulse stem with a 1.0 sample at every beat; launch at transport bar 1; assert over 5 minutes that every backing impulse frame equals the click grid frame (`round(j * intervalFrames)`) for that beat within 0 frames at bar starts and <= 1 frame inside bars (C3). Also: tempo mismatch yields silence (C4); queued launch at bar 3 applies exactly at `barFrame(3)`.
- [ ] **Step 2: Run** `cd android && ./gradlew testDebugUnitTest --tests '*BackingMixerTest*'` — FAIL (class missing). If Gradle unit tests cannot run in this repo, record why in `docs/plans/launchpad/RESULT.md` and fall back to a Dart-side reference mixer test only (Task 3), then re-decide.
- [ ] **Step 3: Implement** `BackingMixer` minimal: stems as `ShortArray`, per-stem gain (smoothed 5 ms), command queue applied when `chunkEnd > boundary`, re-anchor each bar.
- [ ] **Step 4: Run** — PASS. **Step 5: Commit** `feat(android): BackingMixer frame-exact mixing (spike)`.

### Task 2: Wire the mixer into `MetronomeEngine` and measure on device

**Files:** Modify `MetronomeEngine.kt` (mix after the click loop at `scratch`, before `pcm[i] = ...`), `MainActivity.kt` (channel methods), `lib/providers/metronome_runtime_providers.dart` (`PlatformMetronomePlaybackClient`: `backingLoad/backingCommand/backingGain` + incoming `backingState`), Test: `test/providers/platform_backing_channel_test.dart`.

**Interfaces:**
- Channel `com.flowgroove/metronome` methods: `backingLoad({paths: List<String>, sampleRate: int, renderBpm: double, beatsPerBar: int})`, `backingCommand({token, kind, fromBar, toBar, loop, quantize})`, `backingGain({stem: int, gain: double})`, `backingClear()`. Native -> Dart: `backingState({token, state: 'queued'|'playing'|'stopped'|'muted_tempo', bar: int})`, `bar({index: int})`.
- Dart: `Future<int> engineSampleRate()` (new channel method) so stems are rendered at the device rate; stems are written as raw little-endian Int16 files in the cache dir.

- [ ] **Step 1: Test (Dart, fake channel)**: `backingLoad passes paths+renderBpm`; `backingState events reach the stream`; `fallback client ignores backing calls without throwing`.
- [ ] **Step 2:** `flutter test test/providers/platform_backing_channel_test.dart` — FAIL. **Step 3:** implement. **Step 4:** PASS.
- [ ] **Step 5: Device measurement (A24, P30)**: install release over existing; play `AUD_CT1445.mid` (render at 123 BPM) with `sox rec` of the speaker (never ffmpeg avfoundation); onset offset click vs backing drum hits at loop 1 and at 5 minutes. **Go/no-go**: offset < 3 ms and drift < 1 ms over 5 min. Record in `docs/plans/launchpad/RESULT.md`. **Commit.**

## Phase 1: Sync core

### Task 3: Dart reference mixer for iOS/other native + shared goldens

**Files:** Create `lib/services/audio/engine/backing_mixer.dart`; Modify `lib/services/audio/engine/metronome_scheduler.dart` (`_pumpToTarget` mixes `backing.mix(frames, startFrame)` into each chunk before `pushFrames`); Test `test/services/audio/engine/backing_mixer_test.dart`.

**Interfaces:** Consumes `test/fixtures/backing_golden.json` (Task 1). Produces `class BackingMixer` with the same method names/semantics as the Kotlin class: `load`, `command`, `mix(Float32List out, int chunkStart, {required int engineBpm})`.

- [ ] **Step 1: Tests**: golden vectors identical to Kotlin's; `launch queued at bar 3 starts exactly at bar-3 frame`; `bpm mismatch is silent`; `stall resync (scheduler drops frames) keeps bar alignment`; `5 minute simulation: click onset frames == backing impulse frames at bar starts`.
- [ ] **Step 2:** FAIL. **Step 3:** implement. **Step 4:** PASS. **Step 5: Commit.**

### Task 4: One backing facade for Dart (replaces direct SoLoud voice playback)

**Files:** Create `lib/services/audio/backing_engine.dart` (interface + `platform` and `unified` implementations), `lib/providers/data/backing_transport_provider.dart`; Modify `lib/providers/data/midi_song_practice_provider.dart` (render only; no playback), `lib/services/audio/midi/midi_track_renderer.dart` (render at engine rate, pad every stem to whole bars); Test `test/providers/backing_transport_test.dart`.

**Interfaces:**
- Produces: `abstract class BackingEngine { Future<void> load(BackingStems s); Future<void> command(BackingCommand c); void setGain(int stem, double g); Stream<BackingState> get states; }`; `class BackingStems { List<Int16List> stems; List<String> stemNames; int sampleRate; double renderBpm; int beatsPerBar; int bars; }`.
- Provider: `backingTransportProvider` (NotifierProvider, keep-alive): `state { SectionPadState pads, int? playingSection, int? queuedSection, int songBar, bool rendering }`; methods `launch(String sectionId)`, `stop({bool atBar})`, `setLoop(bool)`, `setQuantize(Quantize)`, `soloStem/muteStem/minusOne(String role)`.

- [ ] **Step 1: Tests (fake `BackingEngine`)**: `tap pad while stopped sends start with count-in then launch(fromBar)`; `tap pad while playing sends queued launch, state shows queued until engine reports playing`; `bpm change sets rendering and sends backingClear, re-renders, reloads, resumes at next bar`; `Speed 80% renders at 0.8x and is audible only when engine bpm matches`; `minusOne mutes the stem of that role`; `old direct SoLoud start path is never called`.
- [ ] **Step 2:** FAIL. **Step 3:** implement. **Step 4:** PASS, then `flutter test test/midi test/providers`. **Step 5: Commit.**

### Task 5: Arrangement data and setup sheet

**Files:** Modify `lib/models/midi_song.dart` (`startBar`, `sectionMap`, `useFileTempo`, `endBehavior`, `SectionSpan`), `lib/services/audio/midi/smf_song_parser.dart` (markers -> `MidiSongData.markers`), Create `lib/widgets/midi/arrangement_sheet.dart`, Tests `test/models/midi_arrangement_test.dart`, `test/widgets/arrangement_sheet_test.dart`.

- [ ] **Step 1: Tests**: JSON round-trip with and without new fields; `factsOf(AUD_CT1445) -> bpm 124.0, bars 16, leadInBars 1`; `prefill divides 16 bars across 4 sections as 4/4/4/4`; `markers prefill names`; `save writes via labRepository.saveEntry only for editors`; band viewer read-only.
- [ ] **Step 2-5:** red, implement, green, commit.

## Phase 2: Launchpad UI

### Task 6: Pads, transport row, instrument strip, section card

**Files:** Create `lib/widgets/practice/launchpad_view.dart`, `section_pad.dart`, `instrument_strip.dart`, `section_card.dart`; Modify `lib/screens/metronome_screen.dart` (replace the `_MetronomeSongLibrary` backing area), reuse in `concert_mode_screen.dart` later; Tests `test/widgets/launchpad_view_test.dart`.

- [ ] **Step 1: Tests**: pad states idle/queued/playing have distinct text/icon (not colour only); tap -> `launch(sectionId)`; long-press -> loop-only; 12 sections wrap without overflow at 360 dp and 2.0 text scale; instrument chips Mute/Solo/I play this; section card shows `chordChart` of the playing section and the queued one while queued; no map -> single "Song" pad; semantics labels read "Chorus, queued, starts next bar".
- [ ] **Step 2-5:** red, implement, green, commit.

## Phase 3: Drums and practice features

### Task 7: Drum patterns as a stem

**Files:** Modify `lib/services/audio/midi/drum_loop_renderer.dart` consumers, `lib/providers/data/drum_practice_provider.dart` (stop using `drum_player_soloud` for the practice path), Tests `test/providers/drum_stem_test.dart`.

- [ ] **Step 1: Tests**: `drum pattern becomes a one-stem BackingStems looped over N bars`; `selecting a pattern replaces any MIDI source` (single active source); `old Sync with click toggle removed or always on`.
- [ ] **Step 2-5:** red, implement, green, commit.

### Task 8: Speed trainer and tempo ramp compatibility

- [ ] Decide with the user whether `activeTempoRamp` is allowed with backing (default: ramp pauses backing or steps re-render each N bars). Test: `ramp step re-renders and swaps on a bar line`. (Open question; do not implement before answered.)

## Phase 4: Verify and release

### Task 9: Full verification and device pass

- [ ] **Step 1:** `set -o pipefail; flutter analyze lib test 2>&1 | grep error; flutter test 2>&1 | tail -20` and `cd android && ./gradlew testDebugUnitTest` all green.
- [ ] **Step 2: Device pass (A24, P30, install over existing)**: attach `AUD_CT1445.mid`; setup sheet; Play with count-in 0/1/2; tap pads while playing (queued then switches on the bar line); BPM change mid-play (backing mutes, returns on a bar line); background and screen off for 2 minutes; Bluetooth connect mid-play; compare `sox rec` offsets with Task 2.
- [ ] **Step 3:** from `second01`: `make release LEVEL=minor`, `make deploy-app-hosting`, `make deploy-pages`; confirm `version.json` on both. (Web hides backing.)

## Out of scope

Web engine port; audio stems from files; cell-level clip launching per instrument (full Ableton grid); MIDI editing; auto-detecting sections from audio.

## Self-review

- Coverage: C1-C7 map to Tasks 1-4 (engine + facade), 5 (arrangement), 6 (UI), 7 (drums). Findings 1-6 each drive a task.
- Types: `BackingMixer`, `BackingCommand`, `BackingStems`, `BackingEngine`, `backingTransportProvider`, `SectionSpan` used consistently.
- Risk order: Task 1-2 are a go/no-go; nothing after them starts if offset/drift fails.
