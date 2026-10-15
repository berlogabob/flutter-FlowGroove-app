# MIDI drum practice, reuse-first, low-risk

## Context
Attach MIDI drum patterns to a song, play them at the song's BPM with per-lane mute/solo, light up a drum kit as hits play, and let the user write new patterns for songs in progress. Logbook = Song Lab (`labEntries`) + `practiceSessions`. Drums only now; pitched instruments deferred (needs a soundfont synth, separate decision).

## What we already have (and what we deliberately do NOT touch)
| Need | Reuse | Rejected (risk) |
|---|---|---|
| Per-song storage | `SongLabEntry` + `FirestoreLabRepository` (personal+band paths, rules whitelist, honest-save, band-edit gating already done). Add `LabEntryType.midi`; payload = JSON `events` in a new optional field. | New `midiTracks` subcollection = new repo + firestore.rules in 2 places + rules deploy. |
| Logbook | Free: a drum pattern IS a lab entry, shows in Song Lab history. Add `midiTrackId`/`entryId` to `MetronomeSession` (optional field). | Separate logbook plumbing. |
| Old-build safety | `LabEntryType.parse` falls back to `note` (song_lab.dart:24). Old builds show it as a note; risk only if an old build edits+re-saves it (known full-doc set hazard), acceptable, mention in release notes. | |
| Tempo follow | `MetronomeNotifier.activeSong`, `loadSongTempo`, same BPM state the click uses. | |
| Audio | Do NOT modify `MetronomeScheduler`/`PcmClickRenderer`/`SoloudSink` (timing is hard-won: tuner/metronome memories). Instead pre-render each drum lane of the 1-4 bar pattern to a looping PCM buffer at current BPM (pure Dart, ms to render) and loop it on a separate SoLoud handle (native) / `AudioBufferSourceNode.loop=true` (web, add one method to `audio_engine_web.dart`). Per-lane loops started together; mute/solo = per-handle volume (instant, no re-render). BPM change = re-render + restart on next bar. | Mixing samples into the metronome PCM pipeline (touches the tuned scheduler). |
| UI | `metronome_pattern_editor.dart` as base for the step grid; metronome transport for start/stop; `song_library_block.dart` for song context. | New screens/routes. Panel inside MetronomeScreen only. |
| Import | `FilePicker.pickFile` + `readAsBytes` pattern from `lab_recording_sheet.dart`. | Storing .mid in Storage (rules + 25MB path); events live in the doc. |

Unverified assumption (spike first): SoLoud looped-handle start is close enough to the click start (target <15 ms drift, no cumulative drift since the loop is one buffer). If the spike fails, fall back to mixing into the PCM chunk (original plan). Verify with `sox rec` onset comparison, not by ear.

## Design
- `lib/models/midi_pattern.dart`: `{name, bars, timeSig, stepsPerBeat(4), events:[{step,note,vel}]}`; GM drum notes -> lanes via `drum_map.dart` (kick 36, snare 38, closed/open hat 42/46, toms 41-50, crash 49, ride 51). Serialized into `SongLabEntry` new field `midi` (nullable). Cap events (~2k) at import.
- `lib/services/audio/midi/smf_parser.dart`: pure Dart SMF reader (ch.10 -> drums, quantize to 16ths, take first N bars, ignore source tempo). Check pub for a maintained package first; otherwise ~200 lines.
- `lib/services/audio/midi/drum_loop_renderer.dart`: pattern + bpm + lane samples -> Float32/s16 buffer per lane. Samples: ~12 CC0 hits in `assets/sounds/drums/` + LICENSE note (the `assets/sounds` dir is already declared in pubspec).
- `DrumPlayer` (native soloud / web via conditional export like `tone_generator.dart`): `load(pattern,bpm)`, `start(atBarBoundary)`, `setLaneGain`, `stop`.
- `DrumKitView` CustomPainter: pads flash on hit (driven by `WallClockScheduler` + step index, same clock as audio), plus 1-bar lookahead lane strip. Mute/solo chips per lane.
- `DrumGridEditor`: lane x step toggles, tap velocity cycle, 1-4 bars, save -> lab entry. Import button -> parse -> editor preview -> save.

## Execution split (Claude tokens minimal)
Claude: this plan, per-task specs (file paths, signatures, acceptance test), verification only. Per memory: Codex = default OpenAI cloud (cannot run tests in its sandbox); pi = Unsloth Studio over LAN (key in ~/.pi/agent/models.json), never point Codex at Studio; run via `scripts/plan_run.py` (no nohup, full-suite gate after each task, sequential, separate worktree).
- pi (Studio): pure-Dart units with tests: `smf_parser`, `drum_map`, `drum_loop_renderer`, `midi_pattern` model + serialization. Spec'd by fixture + assert.
- Codex: wiring and UI: `LabEntryType.midi` + lab filter, `DrumPlayer` native/web, `DrumKitView`, `DrumGridEditor`, MetronomeScreen panel, session field.
- Me/you: run `flutter test` (pipefail, read Failing block), sox timing check, device tap-through (iPad has no UI automation; P30 via adb; web via Playwright semantics).
Tasks (each ends with the full suite green):
0. Spike: looped drum buffer vs click drift (native + web). Go/no-go.
1. Model + parser + renderer + drum_map + samples (pi).
2. DrumPlayer native/web + mute/solo (codex).
3. Lab type + repo field + logbook entry/ session link + import flow (codex).
4. DrumKitView + lookahead strip + MetronomeScreen panel (codex).
5. Grid editor create/edit (codex).
6. Verify + release notes (me). Deferred: pitched instruments/soundfont, Maxwell `.mid` export.

## Verification
- Unit: parser fixtures (GM loop, type-1 multi-track, tempo-change file), render length = bars*beats*60/bpm*sr exactly, lane gain mask.
- Rules: no change expected; confirm existing lab rules tests still pass; no firebase deploy needed.
- Timing: sox-recorded click+drums, onset diff within threshold at 60/120/180 BPM, 30 s no drift; BPM change mid-play resyncs on next bar.
- Manual: import a real .mid, play with song BPM, solo kick, watch flashes align, create a pattern, see it in Song Lab history, band viewer cannot edit.
