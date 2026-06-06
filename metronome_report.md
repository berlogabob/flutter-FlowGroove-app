# Flutter RepSync App — Metronome Analysis Report

## 1. Architecture Overview

The metronome is a **dual-implementation** system:

| Layer | Technology | File(s) |
|-------|-----------|---------|
| **Dart/Flutter** | Riverpod state machine + Timer-based scheduling | `metronome_provider.dart`, `metronome_runtime_providers.dart` |
| **Mobile Audio** | `audioplayers` package (PCM WAV synthesis) | `audio_engine_mobile.dart` |
| **Web Audio** | Web Audio API via `package:web` | `audio_engine_web.dart` |
| **Native Android** | MethodChannel `com.flowgroove/metronome` | `PlatformMetronomePlaybackClient` |
| **Native Android (Tack)** | Oboe C++ audio engine (separate module) | `Tack/tack-android/` |

**Key observation**: The Flutter app has its OWN metronome implementation (Dart + audioplayers), completely separate from the Tack Android module. The Tack module is a standalone Android app embedded in the repo but NOT used by the Flutter app.

---

## 2. Metronome Data Flow

```
User taps Play
  → MetronomeNotifier.start(bpm, beatsPerMeasure)
    → Updates MetronomeState (isPlaying=true, bpm, timeSignature, accentPattern)
    → Creates MetronomePlaybackConfig.fromState(state)
    → Calls _playbackClient.start(config, onTick, onStopped)
      → PlatformMetronomePlaybackClient.start()
        → Tries native Android via MethodChannel('com.flowgroove/metronome')
        → Falls back to FlutterMetronomePlaybackClient (Timer.periodic)
          → Timer.periodic(config.interval, _handleTick)
            → _audioClient.playClick(isAccent, waveType, volume, frequency)
              → AudioEngine.playClick()
                → Generates PCM WAV bytes (40ms sine/square/triangle/sawtooth)
                → _player.play(BytesSource(pcmBytes))
            → _hapticsClient.lightImpact() (if enabled)
            → onTick(tick) → updates state.currentBeat
```

---

## 3. All Identified Problems

### 3.1 TIMING & STABILITY

#### P1.1 — Timer.periodic is NOT real-time (CRITICAL)
- **File**: `metronome_runtime_providers.dart` line 312
- **Problem**: `Timer.periodic(config.interval, _handleTick)` runs on the Dart event loop. It is subject to:
  - UI thread congestion (build/layout/animation work)
  - Garbage collection pauses
  - Other async operations (Firestore, analytics)
  - Flutter frame rendering (60fps = 16.67ms budget)
- **Impact**: At 240 BPM with 4 subdivisions = 160ms interval, a single GC pause or frame drop causes audible jitter. At 260 BPM with 12 subdivisions = ~19ms interval, ANY frame work causes missed/delayed ticks.
- **Evidence**: No drift compensation, no wall-clock synchronization, no high-priority scheduling.

#### P1.2 — No drift compensation in tick handler
- **File**: `metronome_runtime_providers.dart` lines 315-339
- **Problem**: `_handleTick()` uses `_tickIndex = (_tickIndex + 1) % config.totalTicks` with no wall-clock reference. If Timer fires late, the tick index advances but the actual time is behind. Over time, this accumulates.
- **Impact**: After 1 minute at 120 BPM, even 5ms average jitter = 600ms total drift.

#### P1.3 — Audio + haptic fired sequentially, not in parallel
- **File**: `metronome_runtime_providers.dart` lines 323-335
- **Problem**: Haptic is fired first (`_hapticsClient.lightImpact()`), then audio is fired (`_audioClient.playClick(...)` wrapped in `unawaited()`). The haptic call is synchronous and blocks until the haptic engine responds.
- **Impact**: Haptic latency (5-20ms on some devices) delays the audio tick start.

#### P1.4 — PCM WAV generation on every tick (HIGH)
- **File**: `audio_engine_mobile.dart` lines 79-117
- **Problem**: `_generateClickSound()` generates a complete WAV file (header + PCM data) on EVERY tick. At 44100 Hz, 40ms = 1764 samples = ~3612 bytes per click.
- **Impact**: 
  - CPU cost: ~0.5ms per tick for sample generation + WAV header construction
  - GC pressure: New `Float32List`, `ByteData`, `Uint8List` allocated per tick
  - At 260 BPM with 12 subdivisions = 52 ticks/second = 52 WAV generations/second
- **Note**: `MetronomeSampleGenerator` exists and pre-generates samples, but is NOT used by the main audio path.

#### P1.5 — audioplayers has inherent latency
- **File**: `audio_engine_mobile.dart` line 104
- **Problem**: `audioplayers` package uses platform-specific media players (MediaPlayer on Android, AVAudioPlayer on iOS). These have:
  - Buffering latency (50-200ms first play, 10-50ms subsequent)
  - No low-latency mode on Android (would need Oboe/AAudio)
  - Platform channel overhead per `play()` call
- **Impact**: First beat after stop/start has 100-300ms latency. Subsequent beats have 10-50ms jitter.

#### P1.6 — preWarmPlayers is ineffective
- **File**: `audio_engine_mobile.dart` lines 39-62
- **Problem**: `preWarmPlayers()` sets volume to 0.01 and does a 10ms delay, but never actually plays a buffer. The comment says "Skip playing silent buffer" and "The first real playClick() will complete initialization."
- **Impact**: The first `playClick()` still pays the full initialization cost. Pre-warming is effectively a no-op.

### 3.2 HAPTIC PROBLEMS

#### P2.1 — Haptic uses only lightImpact for all beat types
- **File**: `metronome_runtime_providers.dart` line 325
- **Problem**: `_hapticsClient.lightImpact()` is used for ALL beats (accent, normal, subdivision). There's no distinction between beat strengths.
- **Impact**: User cannot feel the difference between accented and non-accented beats. This is a major UX issue for a metronome.

#### P2.2 — Haptic client has no intensity control
- **File**: `metronome_runtime_providers.dart` lines 81-98
- **Problem**: `MetronomeHapticsClient` only has `lightImpact()`. No `mediumImpact()`, `heavyClick()`, or custom vibration patterns.
- **Impact**: Cannot provide differentiated haptic feedback for accent vs normal vs subdivision beats.

#### P2.3 — Haptic fired before audio, adding latency
- **File**: `metronome_runtime_providers.dart` lines 324-325
- **Problem**: Haptic is called synchronously before the (unawaited) audio call. The haptic system may take 5-20ms to fire, delaying the audio.
- **Impact**: Audio tick is delayed by haptic processing time.

#### P2.4 — No haptic latency calibration
- **Problem**: There's no mechanism to measure or compensate for haptic latency on different devices.
- **Impact**: On devices with slow haptic engines, the vibration arrives noticeably after the sound.

### 3.3 AUDIO QUALITY

#### P3.1 — Click duration is fixed at 40ms
- **File**: `audio_engine_mobile.dart` line 20
- **Problem**: `_clickDuration = 0.04` (40ms) is hardcoded. Different wave types and frequencies may need different durations to sound natural.
- **Impact**: Square/sawtooth waves at 40ms may sound too short/clicky. Sine waves may need longer duration to be audible.

#### P3.2 — No audio ducking/focus management in practice
- **File**: `audio_focus_manager.dart`
- **Problem**: `AudioFocusManager` exists but is never wired into the metronome playback chain. There's no call to `requestFocus()` on start or `releaseFocus()` on stop.
- **Impact**: Metronome continues playing during phone calls, notifications, etc. No automatic pause/resume.

#### P3.3 — Web and Mobile have different audio characteristics
- **File**: `audio_engine_web.dart` vs `audio_engine_mobile.dart`
- **Problem**: Web uses Web Audio API (oscillator + gain node, real-time), Mobile uses audioplayers (PCM buffer playback). The timing characteristics are fundamentally different.
- **Impact**: Metronome feels different on web vs mobile. Web version has lower latency but different sound.

#### P3.4 — Triangle wave formula is incorrect
- **File**: `metronome_sample_generator.dart` lines 142-144
- **Problem**: The triangle wave formula `2.0 * (2.0 * (phase - floor(phase)).abs() - 1.0) * (sin(phase) >= 0 ? 1.0 : -1.0)` is not a standard triangle wave. It multiplies a triangle-like function by a square wave sign, creating a distorted waveform.
- **Impact**: Triangle wave sounds harsh/distorted instead of smooth.

### 3.4 STATE MANAGEMENT

#### P4.1 — MetronomeState is rebuilt on every tick
- **File**: `metronome_provider.dart` line 426
- **Problem**: `_handlePlaybackTick()` calls `state = state.copyWith(currentBeat: tick.index)` on every tick. This triggers a Riverpod state change notification.
- **Impact**: Every widget watching `metronomeProvider` (or `metronomeCurrentBeatProvider`) rebuilds on every tick. At 260 BPM with 12 subdivisions = 52 rebuilds/second.

#### P4.2 — Selective providers still cause frequent rebuilds
- **File**: `metronome_selective_providers.dart`
- **Problem**: `metronomeCurrentBeatProvider` rebuilds on every beat. Any widget watching it (like `CentralTempoCircle`) rebuilds 52+ times/second at high BPM.
- **Impact**: The `CentralTempoCircle` widget rebuilds and repaints on every beat, causing unnecessary CPU/GPU work.

#### P4.3 — No debouncing for rapid BPM changes
- **File**: `metronome_provider.dart` lines 87-91
- **Problem**: `setBpm()` immediately updates state and calls `_syncPlaybackConfig()` on every call. If user drags the rotary dial quickly, this triggers dozens of state updates and timer restarts per second.
- **Impact**: Performance degradation during rapid BPM changes.

### 3.5 UX PROBLEMS

#### P5.1 — BPM range is limited to 10-260
- **File**: `metronome_provider.dart` line 395
- **Problem**: `_clampBpm()` limits to 10-260. Professional metronomes typically support 1-600 BPM.
- **Impact**: Users who need very slow (<10) or very fast (>260) tempos cannot use the app.

#### P5.2 — No visual beat indicator sync
- **File**: `central_tempo_circle.dart` lines 59-63
- **Problem**: The pulse animation is triggered by `ref.listen<int>(metronomeCurrentBeatProvider)`, which fires on every state change. The animation duration is 200ms, but at high BPM the next beat arrives before the animation completes.
- **Impact**: At >120 BPM, the pulse animation appears to "stutter" or not complete between beats.

#### P5.3 — Play/pause button pulse animation conflicts with beat pulse
- **File**: `bottom_transport_bar.dart` lines 94-100
- **Problem**: The play/pause button has its own 200ms pulse animation on tap. If user taps play, the button pulses AND the beat indicator pulses simultaneously, causing visual confusion.
- **Impact**: Unclear visual feedback when starting/stopping.

#### P5.4 — No tap tempo feature in the main UI
- **Problem**: `TapBpmWidget` exists in widgets but is not integrated into the metronome screen. The integration test for tap tempo exists but the feature is not accessible.
- **Impact**: Users cannot tap to set BPM.

#### P5.5 — No count-in feature
- **Problem**: No count-in (pre-count) functionality exists. Professional metronomes typically offer 1-4 bars of count-in.
- **Impact**: Users must start playing immediately when metronome starts.

#### P5.6 — No setlist song auto-advance
- **File**: `metronome_provider.dart` lines 218-236
- **Problem**: `nextSetlistSong()` and `previousSetlistSong()` exist but there's no automatic advancement when a song's timer/section ends.
- **Impact**: User must manually tap next/previous for each song in a setlist.

#### P5.7 — BPM dial sensitivity is inconsistent
- **File**: `central_tempo_circle.dart` line 139
- **Problem**: `_onPanUpdate` uses `details.delta.dy` directly. The sensitivity depends on device pixel ratio and screen size. On high-DPI devices, small finger movements cause large BPM changes.
- **Impact**: Hard to set precise BPM values via the dial.

#### P5.8 — No haptic feedback differentiation on dial
- **File**: `central_tempo_circle.dart` line 148
- **Problem**: `HapticFeedback.lightImpact()` fires on every pan update, regardless of BPM change magnitude.
- **Impact**: Constant buzzing during dial adjustment, no "notch" feel at integer BPM values.

### 3.6 CODE QUALITY

#### P6.1 — Two separate audio engines (AudioEngine + ToneGenerator)
- **Files**: `audio_engine_mobile.dart` + `tone_generator.dart`
- **Problem**: Two completely separate audio synthesis implementations exist. `AudioEngine` generates 40ms WAV clicks. `ToneGenerator` generates 10-second WAV tones. They serve different purposes but have overlapping code (WAV header generation, sample synthesis).
- **Impact**: Code duplication, maintenance burden, inconsistent audio quality.

#### P6.2 — MetronomeSampleGenerator is unused in main path
- **File**: `metronome_sample_generator.dart`
- **Problem**: A sophisticated sample generator with caching exists but is only used in `ToneConfigNotifier.testCurrentConfig()`. The main audio path regenerates WAV on every tick.
- **Impact**: Wasted optimization effort. The sample generator's cache is never populated during normal playback.

#### P6.3 — PlatformMetronomePlaybackClient has no iOS implementation
- **File**: `metronome_runtime_providers.dart` lines 361-362
- **Problem**: `_canUseNative` only checks for Android. On iOS, it always falls back to `Timer.periodic`.
- **Impact**: iOS has the same timing issues as the Flutter fallback, with no native optimization path.

#### P6.4 — No error recovery for Timer.periodic
- **File**: `metronome_runtime_providers.dart` lines 308-313
- **Problem**: If `_handleTick()` throws an exception, the Timer continues but the error is silently swallowed (no try-catch in the tick handler).
- **Impact**: A single audio playback failure can cause the metronome to continue "playing" (updating UI) but producing no sound.

#### P6.5 — dispose() doesn't await stop()
- **File**: `metronome_runtime_providers.dart` lines 304-306
- **Problem**: `dispose()` calls `unawaited(stop())`. If stop is still running when the provider is disposed, resources may leak.
- **Impact**: Potential audio player leaks when navigating away from metronome screen.

#### P6.6 — MetronomeService is a thin wrapper (dead code smell)
- **File**: `metronome_service.dart`
- **Problem**: `MetronomeService` is a 111-line wrapper that just delegates to `metronomeProvider`. It exists "for backward compatibility" but adds no value.
- **Impact**: Confusing API surface. New developers don't know whether to use `MetronomeService` or `metronomeProvider` directly.

#### P6.7 — Integration tests don't test actual timing
- **File**: `test/integration/metronome_flow_test.dart`
- **Problem**: Tests verify state changes but never measure actual tick timing, audio latency, or haptic sync.
- **Impact**: Timing regressions are never caught by tests.

---

## 4. Problem Summary Table

| ID | Severity | Category | Description |
|----|----------|----------|-------------|
| P1.1 | CRITICAL | Timing | Timer.periodic is not real-time, causes jitter at high BPM |
| P1.2 | HIGH | Timing | No drift compensation, accumulated error over time |
| P1.3 | MEDIUM | Timing | Haptic fired before audio, adds latency |
| P1.4 | HIGH | Performance | PCM WAV generated on every tick, GC pressure |
| P1.5 | HIGH | Timing | audioplayers has 10-50ms inherent latency |
| P1.6 | LOW | Timing | preWarmPlayers is effectively a no-op |
| P2.1 | HIGH | UX | All beats use same haptic (lightImpact), no differentiation |
| P2.2 | MEDIUM | UX | No intensity control in haptic client |
| P2.3 | LOW | Timing | Haptic blocks audio tick start |
| P2.4 | MEDIUM | UX | No haptic latency calibration |
| P3.1 | LOW | Audio | Fixed 40ms click duration for all wave types |
| P3.2 | MEDIUM | Audio | AudioFocusManager exists but is never used |
| P3.3 | LOW | Audio | Web and Mobile have different audio characteristics |
| P3.4 | LOW | Audio | Triangle wave formula is incorrect |
| P4.1 | MEDIUM | Performance | Full state rebuild on every tick |
| P4.2 | MEDIUM | Performance | Widgets rebuild 52+ times/second at high BPM |
| P4.3 | LOW | Performance | No debouncing for rapid BPM changes |
| P5.1 | LOW | UX | BPM limited to 10-260 |
| P5.2 | MEDIUM | UX | Pulse animation stutters at high BPM |
| P5.3 | LOW | UX | Play/pause animation conflicts with beat pulse |
| P5.4 | MEDIUM | UX | Tap tempo not integrated into main screen |
| P5.5 | LOW | UX | No count-in feature |
| P5.6 | MEDIUM | UX | No automatic setlist song advance |
| P5.7 | LOW | UX | BPM dial sensitivity inconsistent across devices |
| P5.8 | LOW | UX | No haptic "notch" feel on BPM dial |
| P6.1 | LOW | Code | Two separate audio engines with overlapping code |
| P6.2 | MEDIUM | Code | MetronomeSampleGenerator unused in main path |
| P6.3 | MEDIUM | Code | No iOS native playback implementation |
| P6.4 | MEDIUM | Code | No error recovery in tick handler |
| P6.5 | LOW | Code | dispose() doesn't await stop() |
| P6.6 | LOW | Code | MetronomeService is a thin wrapper |
| P6.7 | MEDIUM | Code | No timing tests in integration suite |

---

## 5. Recommended Fix Priority

### Immediate (P0) — Stability
1. **P1.1**: Replace `Timer.periodic` with a dedicated high-priority timer or use `Isolate` for tick scheduling
2. **P1.4**: Use pre-generated samples from `MetronomeSampleGenerator` instead of generating WAV on every tick
3. **P1.5**: Consider using `flutter_soloud` or `dart:ffi` + Oboe for low-latency audio on Android

### Short-term (P1) — UX
4. **P2.1**: Add differentiated haptic feedback (heavyClick for accent, lightImpact for normal, none for subdivision)
5. **P5.2**: Fix pulse animation to use `AnimationController` with proper duration relative to BPM
6. **P4.1**: Use `select()` or `distinct:` to prevent unnecessary widget rebuilds on beat changes

### Medium-term (P2) — Features
7. **P5.4**: Integrate tap tempo into main screen
8. **P5.5**: Add count-in feature
9. **P3.2**: Wire up `AudioFocusManager` into playback chain
10. **P5.6**: Add automatic setlist song advance

### Long-term (P3) — Architecture
11. **P6.1**: Consolidate `AudioEngine` and `ToneGenerator`
12. **P6.3**: Implement iOS native playback via AVAudioEngine
13. **P6.7**: Add timing accuracy tests
