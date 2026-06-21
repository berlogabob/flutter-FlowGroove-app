# Metronome Audio Engine — Premium-Stability Redesign (Design Spec)

> Status: **approved design**, 2026-06-21. Core-feature rebuild of the metronome audio path for
> premium cross-platform stability. Companion to the working plan
> `docs/superpowers/plans/2026-06-21-metronome-robustness.md` (which this spec supersedes for the
> long-term architecture). Next step after sign-off: `writing-plans` → implementation plan.

## 1. Background & motivation

The metronome is a core feature and must be the best it can be on **Android, iOS, Web, and Desktop**.

Two root causes were found by investigation (see memory `metronome-bluetooth-route-bug`):

1. **Bluetooth kills playback.** The PCM-timeline engine feeds a `flutter_soloud` `setBufferStream`
   whose miniaudio output device is bound once at `init()` and does not follow audio-route changes; a
   BT connect/disconnect orphans the device and the stream goes permanently silent
   (`BufferingType.released` never resumes). Nothing listens for route changes.
2. **Subdivision stumble on the SoundPool fallback.** Switching the Android default to the native
   `AndroidMetronomeEngine` (SoundPool) fixed Bluetooth but exposed SoundPool's variable play-latency;
   at subdivisions > 1 (short intervals, alternating pitches) the jitter is audible. SoundPool is a
   game-SFX player, not a sample-accurate one — the exact reason the reference app (Tack) uses Oboe.

Reference comparison: **Tack** (`~/Documents/GitHub/tack/tack-android`, `docs/analysis/*`) achieves
premium timing via a strict layer split, a native real-time engine (Oboe), sample-accurate scheduling,
absolute-time drift correction, voice pooling, stream-disconnect recovery, and user latency
calibration. We adopt these **principles** (not the code) and improve on its weaknesses (god class,
per-platform fork).

**Key realization:** we already own the hard part — our PCM-timeline scheduler mixes clicks into a
buffer at exact sample offsets, the same sample-accuracy Tack gets from Oboe, done engine-agnostically.
Its only real flaw was device-binding. So the redesign **protects the sample-accurate core and makes
the output device-resilient**, rather than introducing a new engine.

## 2. Goals / non-goals

**Goals**
- Sample-accurate timing for any subdivision/polyrhythm/swing/accent/count-in — no stumble, no drift.
- Survive audio-route changes (Bluetooth connect/disconnect, wired unplug, device switch) with no
  permanent silence and no lost beat.
- One shared core across Android/iOS/Web/Desktop; no per-platform engine fork.
- User-calibratable output-latency offset + sensible per-route defaults.
- Timing brain is automatically testable (CI), not dependent on manual on-device runs.
- Reuse the maintained engine we already ship (`flutter_soloud` / miniaudio); keep a clean upgrade
  path to a custom C sink without touching the scheduler.

**Non-goals (YAGNI)**
- No custom C/FFI native engine in v1 (kept as a future drop-in sink only).
- No per-platform native engines (Oboe/AVAudioEngine/WASAPI) — rejected as the fork trap.
- No new musical features beyond what the app already exposes; this is a stability/quality rebuild.
- No change to the band/setlist → metronome load path (already verified correct).

## 3. Architecture — three layers, split by "who may block"

```
┌─ LAYER 1 · CONTROL  (Dart main isolate — may GC/jank freely) ───────────┐
│  UI · gestures · MetronomeState · settings · persistence · setlist load │
│  Owns tempo/beats/subdivisions/beatModes/accents/swing/count-in/        │
│  latency-offset. Decisions ONLY. No audio APIs.                         │
└───────────────────────────────┬─────────────────────────────────────────┘
              immutable MetronomeConfig snapshots (SendPort)
┌─ LAYER 2 · SCHEDULER/RENDERER  (dedicated Dart isolate) ────────────────┐
│  Sample-accurate PCM timeline (our current core, relocated):            │
│   absolute-frame positioning · mixes clicks into PCM chunks at exact    │
│   sample offsets · pre-buffers ahead · subdivision/polyrhythm/swing/    │
│   count-in/accent all sample-mixed. Emits PCM frames + UI-tick events.  │
└───────────────────────────────┬─────────────────────────────────────────┘
                     PCM frames  │  (push to sink)
┌─ LAYER 3 · OUTPUT SINK  (platform, swappable behind one interface) ─────┐
│  AudioSink:                                                             │
│   NativeSoLoudSink (flutter_soloud→miniaudio: Android/iOS/desktop)      │
│   WebAudioSink     (AudioWorklet: web)                                  │
│   [future] MiniaudioFfiSink (custom C — drop-in if SoLoud falls short)  │
│  Owns device lifecycle + DEVICE-CHANGE RECOVERY + audio focus.          │
└───────────────────────────────┬─────────────────────────────────────────┘
                                 ▼  OS audio device / speaker / BT
```

**Boundaries (each independently understandable & testable):**
- **L1 decides, never renders.** Hands down immutable `MetronomeConfig`; touches no audio API.
- **L2 renders, never sets policy.** Pure function `(config, sampleClock) → PCM frames + tick events`;
  no platform deps → unit-testable on the Dart VM.
- **L3 plays bytes, owns the device.** Knows nothing about beats; tiny contract; swappable per platform.

**Why the dedicated isolate:** today the renderer/feed-timer runs on the main isolate and competes
with UI rebuilds/GC. Moving L2 to its own isolate means UI work can never jitter audio (Tack practice
#3 — timing off the UI thread). Buffer-ahead already tolerates GC; the isolate makes it bulletproof.

## 4. Component contracts

### 4.1 `MetronomeConfig` (L1 → L2 message)
Immutable snapshot: `bpm`, `beats`, `subdivisions`, `beatModes` (2D), `accentEnabled`,
`accentFrequency`, `beatFrequency`, `waveType`, `volume`, `countInBars`, `swing`, `latencyOffsetMs`.
Sent to the scheduler isolate via `SendPort` on any change (debounced as today).

### 4.2 `AudioSink` (L2/L3 boundary)
```dart
abstract class AudioSink {
  Future<void> open({required int sampleRate, required int channels});
  void pushFrames(Float32List pcm);            // L2 feeds rendered audio
  int get framesQueued;                         // buffer-ahead control
  Stream<SinkEvent> get events;                 // deviceChanged | underrun | error | focusLost/Gained
  Future<void> recover({required int atFrame}); // rebuild stream, resume at sample position
  Future<void> close();
}
enum SinkEventType { deviceChanged, underrun, error, focusLost, focusGained }
```
Implementations: `NativeSoLoudSink`, `WebAudioSink`, future `MiniaudioFfiSink`. L1/L2 are unchanged
when a sink is swapped.

### 4.3 Scheduler (L2)
Works in **absolute sample frames**; the audio device clock is the source of truth:
```
secondsPerSubdivision = 60 / bpm / subdivisions
frameForTick(n)       = round(n * secondsPerSubdivision * sampleRate)
mixPosition(n)        = frameForTick(n) - latencyFrames
```
Each click is mixed at `mixPosition(n)`. Positions derive from an absolute frame counter (never
`previous + interval`), so per-tick error cannot accumulate — sample-level zero-drift. Subdivisions /
polyrhythm are multiple tick streams mixed into the same buffer. Overlapping clicks **sum** (clamped
for headroom) — no stream-count ceiling, no voice-cut, no fallback tone.

## 5. Device-change recovery (fixes Bluetooth)

```
BT connects / unplug / output device swaps
   platform reports it ──┬─ Android: AudioDeviceCallback (onAudioDevicesAdded/Removed)
                         ├─ iOS:     AVAudioSession.routeChangeNotification
                         └─ miniaudio device-stopped notification (backup signal)
   sink emits SinkEvent.deviceChanged
   L2 scheduler:  (a) record current absolute frame X
                  (b) pause feeding
                  (c) sink.recover(atFrame: X) → close, re-open at NEW device's native
                       sample rate, recreate buffer
                  (d) resume rendering from frame X  → no beat lost, no drift
```

Root-cause fixes baked in:
- **No device-binding:** sink re-opens at the new device's native sample rate (kills hardcoded-44100 /
  48000 mismatch) instead of staying bound to its birth device.
- **No permanent silence:** drop `BufferingType.released`; add an **underrun watchdog**
  (`SinkEvent.underrun` → re-prime); a dead stream is rebuilt within ~1 click, not forever.
- **Audio focus** lives in the sink (device policy, not beat logic): `OnAudioFocusChangeListener`
  (Android) / `AVAudioSession` interruptions (iOS) → duck/pause/resume — implements the half currently
  a dead stub (`MethodChannel('com.flowgroove/audio')` had no native handler).

## 6. Latency calibration
- User **offset slider (ms)**, persisted, subtracted at mix time via `latencyFrames`.
- **Per-route default**: detect BT vs wired vs speaker, pre-load a sensible offset (BT larger), so it's
  close before manual calibration.
- Future option: tap-to-calibrate measuring perceived offset.

## 7. Test strategy

| Layer | Test | Proves |
|---|---|---|
| L2 renderer | Dart-VM unit tests: render N seconds, assert click energy at exact `frameForTick(n)` (±0 drift) for subdivisions 1–12, polyrhythm, swing, count-in | Timing mathematically correct; stumble cannot regress |
| Recovery logic | Unit test with `FakeAudioSink` emitting deviceChanged/underrun/error; assert resume at right frame, no double-play, no gap | BT recovery correct as a state machine |
| Latency offset | Unit test: offset shifts every click by exactly `latencyFrames` | Calibration correct |
| Sinks (device I/O) | Manual on-device checklist (real BT hardware): 10-min runs, 5× connect/disconnect, route switches, per platform | Real hardware behaves |

The entire timing + recovery brain is automated in CI; only the irreducible "does this hardware
behave" stays manual.

## 8. Migration / rollout
1. Build L2 scheduler + `AudioSink` interface behind a feature flag; keep current path as fallback.
2. Land `NativeSoLoudSink` with recovery; validate on-device that SoLoud rebuilds its stream on route
   change without a glitch. **Decision gate:** if SoLoud cannot recover cleanly, implement
   `MiniaudioFfiSink` (custom C) — scheduler unchanged.
3. Land `WebAudioSink` (reuse/extend existing Web Audio engine).
4. Move scheduler to dedicated isolate.
5. Add latency calibration UI + per-route defaults.
6. Remove the legacy SoLoud PCM-timeline-on-main-isolate path and the SoundPool engine once parity is
   verified on all platforms. Re-evaluate `enablePcmTimelineEngine` flag (currently `false` for the
   interim SoundPool stopgap).

## 9. Risks
- **SoLoud route recovery may glitch or be impossible** → mitigated by the `AudioSink` interface; cost
  of escalation is the sink only (Decision gate, §8.2).
- **Dedicated-isolate PCM transfer overhead** → buffer-ahead with seconds of lead absorbs it; measure.
- **Web AudioWorklet parity** (sample rate, buffering) → web already has a separate engine; treat as
  its own sink with the same scheduler contract.
- **Per-platform device-notification quirks** → backup signal via miniaudio device-stopped + an
  underrun watchdog so recovery triggers even if a platform callback is missed.

## 10. Improvements over the reference (Tack)
- **No god class:** L1 splits decisions / `MetronomeConfig` / persistence (Tack's `MetronomeEngine`
  mixes ~21 concerns).
- **No per-platform fork:** one Dart scheduler + thin sinks vs Tack's byte-duplicated app/wear native
  engines.
