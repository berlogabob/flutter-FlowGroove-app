# Metronome Fix Implementation Plan

> **For Hermes:** Use subagent-driven-development to implement this plan task-by-task.

use omlx launch pi with model NousCoder-14B-mlx-4Bit for subagent-driven-development. run only 1 instance at a time.

**Goal:** Fix all identified metronome issues — timing stability, audio latency, haptic feedback, and UX.

**Architecture:** Replace `Timer.periodic` + `audioplayers` with a wall-clock drift-compensating scheduler + `flutter_soloud` for low-latency PCM. Pre-generate all audio samples at init. Fire haptics in parallel with audio.

**Tech Stack:** Dart 3.11+, Flutter, Riverpod, flutter_soloud (replaces audioplayers), TDD.

---

## Phase 0: Dependencies & Foundation

### [ ] Task 0.1: Add flutter_soloud
- Modify `pubspec.yaml` — replace `audioplayers: ^6.6.0` with `flutter_soloud: ^3.1.0`
- Run `flutter pub get`

### [ ] Task 0.2: Create WallClockScheduler
- Create `lib/services/audio/wall_clock_scheduler.dart`
- Uses `Stopwatch` + `Timer.periodic` with drift compensation
- `start(interval, callback)`, `stop()`, `elapsedMilliseconds`
- Pre-generated sample cache at init — zero allocation during playback
- Test: `test/services/wall_clock_scheduler_test.dart` — verify interval accuracy ±20ms

### [ ] Task 0.3: Create MetronomeAudioEngine
- Create `lib/services/audio/metronome_audio_engine.dart`
- Uses `flutter_soloud` (SoLoud) for sub-10ms audio latency
- Pre-generates PCM samples for all frequency/wave combinations at init
- `playClick(isAccent, volume, frequency)` — zero allocation at play time
- Fix triangle wave formula (was `2.0 * (2.0 * (phase - floor) - 1.0) * sign(sin)` → should be `2.0 * 2.0 * abs(phase - floor - 0.5) - 1.0`)
- Test: `test/services/metronome_audio_engine_test.dart`

### [ ] Task 0.4: Delete old audio engines
- Delete `lib/services/audio/audio_engine_mobile.dart`
- Delete `lib/services/audio/audio_engine.dart`
- Delete `lib/services/audio/audio_engine_export.dart`
- Keep `lib/services/audio/audio_engine_web.dart` (web is fine)
- Keep `lib/services/audio/metronome_sample_generator.dart` (used by ToneConfigNotifier)
- Keep `lib/services/audio/tone_generator.dart` (used by tuner path)

---

## Phase 1: Core Timing Fix

### [ ] Task 1.1: Rewrite FlutterMetronomePlaybackClient
- Modify `lib/providers/metronome_runtime_providers.dart` — `FlutterMetronomePlaybackClient`
- Replace `Timer.periodic` with `WallClockScheduler`
- Audio and haptic fired in parallel (both `unawaited`, not sequential)
- Add try-catch around `_handleTick` so single failure doesn't kill playback
- Dispose: `await stop()` instead of `unawaited(stop())`

### [ ] Task 1.2: Wire MetronomeAudioClient to new engine
- Modify `lib/providers/metronome_runtime_providers.dart` — `AudioEngineMetronomeAudioClient`
- Replace `AudioEngine` usage with `MetronomeAudioEngine`
- Pre-warm: call `MetronomeAudioEngine.initialize()` during app startup

### [ ] Task 1.3: Add drift compensation test
- Create `test/services/scheduler_drift_test.dart`
- Measure tick accuracy over 30 seconds at 120 BPM
- Assert: cumulative drift < 50ms over 30 seconds

---

## Phase 2: Haptic Fix

### [ ] Task 2.1: Expand MetronomeHapticsClient interface
- Modify `lib/providers/metronome_runtime_providers.dart`
- Add `heavyClick()`, `mediumClick()`, `tick()` to `MetronomeHapticsClient`
- Implement all methods in `SystemMetronomeHapticsClient` using `HapticFeedback`

### [ ] Task 2.2: Wire differentiated haptics into playback
- Modify `FlutterMetronomePlaybackClient._handleTick()`
- Accent beat → `heavyClick()`, Normal → `mediumClick()`, Subdivision → `tick()`, Silent → none
- Fire haptic and audio in parallel (both `unawaited`)

---

## Phase 3: Performance — Reduce Rebuilds

### [ ] Task 3.1: Add selective provider for current beat
- Modify `lib/providers/metronome_selective_providers.dart`
- Use `select()` to only rebuild on actual beat value changes
- Add `distinct: true` equivalent

### [ ] Task 3.2: Fix CentralTempoCircle rebuild frequency
- Modify `lib/widgets/metronome/central_tempo_circle.dart`
- Replace `ref.listen(metronomeCurrentBeatProvider)` with throttled listener
- Pulse animation duration = min(200ms, intervalMs * 0.8) — never overlap

### [ ] Task 3.3: Debounce rapid BPM changes
- Modify `lib/providers/metronome_provider.dart` — `setBpm()`, `rotateTempo()`
- Add 50ms debounce timer before calling `_syncPlaybackConfig()`
- Cancel previous debounce on each new change

---

## Phase 4: UX Fixes

### [ ] Task 4.1: BPM range 1-600
- Modify `lib/providers/metronome_provider.dart` — `_clampBpm()`
- Change `clamp(10, 260)` → `clamp(1, 600)`
- Update `MetronomePlaybackConfig.interval` clamp: min 1000µs → min 500µs

### [ ] Task 4.2: Dial sensitivity fix
- Modify `lib/widgets/metronome/central_tempo_circle.dart` — `_onPanUpdate()`
- Normalize delta by device pixel ratio: `delta.dy / MediaQuery.devicePixelRatio`
- Add haptic "notch" every 5 BPM: `if (newBpm % 5 == 0) HapticFeedback.selectionClick()`

### [ ] Task 4.3: Wire AudioFocusManager
- Modify `lib/providers/metronome_provider.dart` — `start()` and `stop()`
- Call `AudioFocusManager().requestFocus()` on start
- Call `AudioFocusManager().releaseFocus()` on stop
- Inject `AudioFocusManager` into `MetronomeNotifier`

### [ ] Task 4.4: Add count-in
- Modify `lib/providers/metronome_provider.dart`
- Add `countInBars` field to `MetronomeState` (default: 0)
- In `FlutterMetronomePlaybackClient._handleTick()`, skip audio for first `countInBars * ticksPerBar` ticks but still fire haptics
- Add UI in metronome screen: count-in selector (0, 1, 2, 4 bars)

### [ ] Task 4.5: Integrate tap tempo
- Modify `lib/screens/metronome_screen.dart`
- Add `TapBpmWidget` to tempo circle area (long-press or dedicated button)
- Connect to `metronome.setBpm()`

---

## Phase 5: Error Handling & Cleanup

### [ ] Task 5.1: Add tick error recovery
- Modify `FlutterMetronomePlaybackClient._handleTick()`
- Wrap in try-catch — log error but continue playback
- Track consecutive errors; stop metronome after 10 consecutive failures

### [ ] Task 5.2: Fix dispose chain
- Modify all `dispose()` methods: `await stop()` before cleanup
- Ensure `MetronomeAudioEngine.dispose()` is called on app exit

### [ ] Task 5.3: Delete dead code
- Delete `lib/services/audio/metronome_service.dart` (thin wrapper, unused)
- Delete `lib/services/audio/tone_generator.dart` (unused — only referenced in old code)
- Run `flutter analyze` to verify no breakage

### [ ] Task 5.4: Add timing accuracy test
- Create `test/integration/metronome_timing_test.dart`
- Start metronome at 120 BPM, measure actual tick intervals over 10 seconds
- Assert: 95% of intervals within ±5ms of expected

---

## Files Changed Summary

| Action | File |
|--------|------|
| Modify | `pubspec.yaml` |
| Create | `lib/services/audio/wall_clock_scheduler.dart` |
| Create | `lib/services/audio/metronome_audio_engine.dart` |
| Create | `lib/services/audio/audio_engine_stub.dart` |
| Modify | `lib/services/audio/audio_engine_export.dart` |
| Modify | `lib/providers/metronome_runtime_providers.dart` |
| Modify | `lib/providers/metronome_provider.dart` |
| Modify | `lib/providers/metronome_selective_providers.dart` |
| Modify | `lib/widgets/metronome/central_tempo_circle.dart` |
| Modify | `lib/widgets/metronome/bottom_transport_bar.dart` |
| Modify | `lib/screens/metronome_screen.dart` |
| Delete | `lib/services/audio/audio_engine_mobile.dart` |
| Delete | `lib/services/audio/audio_engine.dart` |
| Delete | `lib/services/audio/metronome_service.dart` |
| Delete | `lib/services/audio/tone_generator.dart` |
| Create | `test/services/wall_clock_scheduler_test.dart` |
| Create | `test/services/metronome_audio_engine_test.dart` |
| Create | `test/services/scheduler_drift_test.dart` |
| Create | `test/integration/metronome_timing_test.dart` |
