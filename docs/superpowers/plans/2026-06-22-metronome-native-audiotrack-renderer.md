# Native Sample-Accurate AudioTrack Renderer (fix background drift + noise)

> Follow-up to the background-foreground-service feature. Fixes the audio-quality
> regression introduced by routing Android playback through the SoundPool engine.

**Goal:** Eliminate the metronome's timing drift ("floating") and click noise in the
Android foreground-service path by replacing the `SoundPool`-per-tick engine with a
continuous, sample-accurate `AudioTrack` (MODE_STREAM) renderer.

**Root cause (confirmed on-device):** `AndroidMetronomeEngine` scheduled each click
with `Handler.postDelayed` (millisecond resolution + thread jitter) and sounded it
with `SoundPool.play()` (non-deterministic playback latency) — so beats float; and
`SoundPool` resamples the 44.1 kHz WAV to the device rate, which adds grit. Neither
is sample-accurate. The Dart `UnifiedEnginePlaybackClient` / `PcmClickRenderer`
(proven 0-drift on-device) avoided both by rendering one continuous PCM timeline with
each click at an exact sample offset, fed to a gapless buffer stream.

**Approach:** Port `PcmClickRenderer` (lib/services/audio/engine/pcm_click_renderer.dart)
to Kotlin and drive a single `AudioTrack` in MODE_STREAM with **blocking writes**.
Blocking writes pace the loop by the audio sample clock — timing is the sample
counter, not Handler/SoundPool latency. This is the standard-SDK equivalent of tack's
Oboe engine (tack pushes pre-rendered click PCM into a native stream via JNI;
`AudioTrack` gets us the same sample-accuracy without NDK).

**Scope:** Android only, one file: `android/app/src/main/kotlin/com/flowgroove/app/MetronomeEngine.kt`.
The MethodChannel contract (`toPlatformMap` → `intervalMicros`, `ticks[]{index,shouldPlay,frequency}`,
`waveType`, `volume`, `hapticsEnabled`), the service, MainActivity wiring, and the Dart
client selection all stay exactly as they are. `NativeMetronomeConfig`/`NativeMetronomeTick`
parsing and `vibrate()` are kept; `SoundPool`, `ToneGenerator`, the WAV `ClickSampleGenerator`,
and the `postDelayed` tick loop are removed.

## Design

- **AudioTrack:** MODE_STREAM, `USAGE_MEDIA` / `CONTENT_TYPE_MUSIC` (follows BT/wired
  routes like SoundPool did), 16-bit PCM, mono, device output sample rate
  (`AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE`, fallback 48000). Low-latency performance
  mode on API 26+.
- **Render thread:** a single worker `Thread` runs the loop: render a ~20 ms chunk into
  a float scratch buffer, convert to Int16, `audioTrack.write(..., MODE_STREAM)` (blocks
  until the buffer drains → real-time pacing), advance an absolute `framesWritten`
  counter.
- **Sample-accurate click placement (port of `PcmClickRenderer.renderChunk`):** for each
  chunk window `[chunkStart, chunkEnd)`, find every tick `j` (since the current epoch)
  whose 40 ms voice overlaps the window — including a click that started in the previous
  chunk (its tail) — and mix it at sample offset `tickFrame - chunkStart`.
  `tickFrame = epochFrame + round(j * intervalFrames)`, `intervalFrames = sampleRate *
  intervalMicros / 1e6`. The tick's list entry is `ticks[(initialTick + 1 + j) mod size]`.
- **Click voice (port of `_mixVoice`/`_oscillator`):** 40 ms (`round(sr*0.04)` samples),
  linear 44-sample attack then `exp(-4*(k-44)/(voiceLen-44))` decay, `outputGain = 2.2`,
  per-sample sum-and-clamp to [-1, 1]. Same sine/square/triangle/sawtooth oscillators as
  the Dart renderer, so it sounds identical to the foreground engine the user liked.
- **UI/haptics sync:** queue `(tickFrame, index)` for each click whose onset lands in the
  chunk; after each write, read `audioTrack.playbackHeadPosition` and fire `onTick(index)`
  (+ `vibrate()` if enabled) for queued ticks whose frame has reached the audible head —
  so the beat highlight and vibration align with what's actually playing.
- **Live update (BPM/pattern/pitch while playing):** `update()` stashes the new config in
  a `@Volatile pendingConfig`; the render loop swaps it at the next chunk boundary, sets
  `epochFrame = framesWritten`, and continues gaplessly at the new interval.
- **Lifecycle:** `start` builds + `play()`s the track and starts the thread; `stop` sets
  `playing=false`, joins the thread (so no write races the release), then `stop/flush/release`s
  the track; `dispose` = stop.

## Task 1: Replace the native engine audio core with the AudioTrack renderer

**File:** rewrite `android/app/src/main/kotlin/com/flowgroove/app/MetronomeEngine.kt`
(keep `NativeMetronomeTick`, `NativeMetronomeConfig`, the `AndroidMetronomeEngine(context,
onTick, onStopped)` constructor + `start/update/stop/dispose` signatures, and `vibrate()`).

**Gate:** `flutter build apk --debug` BUILD SUCCESSFUL (native timing is not unit-testable
in this repo; on-device acceptance is the user's: no drift/float, clean clicks, app-switch/
screen-off/call continuity preserved, BPM/pattern/pitch changes apply live).

Steps:
1. Rewrite the file with the `ClickRenderer` (pure mixing/oscillator) + the `AudioTrack`-based
   `AndroidMetronomeEngine`, removing `SoundPool`/`ToneGenerator`/WAV/`postDelayed`.
2. `flutter build apk --debug` → BUILD SUCCESSFUL.
3. Commit: `fix(android): sample-accurate AudioTrack metronome engine (no drift, clean clicks)`.

## Notes
- minSdk (Flutter 3.44 default) supports `AudioTrack.Builder` (API 23) and
  `PROPERTY_OUTPUT_SAMPLE_RATE` (API 17); guard `PERFORMANCE_MODE_LOW_LATENCY` with API 26.
- No Dart change: the engine's MethodChannel contract is unchanged. The three-pitch
  per-tick frequencies already arrive via `toPlatformMap()` and are mixed at their exact
  frames — same sound as the foreground engine.
