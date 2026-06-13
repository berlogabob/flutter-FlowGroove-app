# Metronome Fix Implementation Plan

> **For Hermes:** Use subagent-driven-development to implement this plan task-by-task.

**Goal:** Fix all identified metronome issues — timing stability, audio latency, haptic feedback, and UX.

**Architecture:** Replace `Timer.periodic` + `audioplayers` with a wall-clock drift-compensating scheduler + `flutter_soloud` for low-latency PCM. Pre-generate all audio samples at init. Fire haptics in parallel with audio.

**Tech Stack:** Dart 3.11+, Flutter, Riverpod, flutter_soloud (replaces audioplayers), TDD.

**Status:** COMPLETE — All 20 tasks done across 5 phases. 10 commits on branch `second01`.

---

## Phase 0: Dependencies & Foundation

### [x] Task 0.1: Add flutter_soloud
- Modify `pubspec.yaml` — replace `audioplayers: ^6.6.0` with `flutter_soloud: ^3.1.0`
- Run `flutter pub get`

### [x] Task 0.2: Create WallClockScheduler
- Create `lib/services/audio/wall_clock_scheduler.dart`
- Uses `Stopwatch` + `Timer.periodic` with drift compensation
- `start(interval, callback)`, `stop()`, `elapsedMilliseconds`
- Pre-generated sample cache at init — zero allocation during playback
- Test: `test/services/wall_clock_scheduler_test.dart` — verify interval accuracy ±20ms

### [x] Task 0.3: Create MetronomeAudioEngine
- Create `lib/services/audio/metronome_audio_engine.dart`
- Uses `flutter_soloud` (SoLoud) for sub-10ms audio latency
- Pre-generates PCM samples for all frequency/wave combinations at init
- `playClick(isAccent, volume, frequency)` — zero allocation at play time
- Fix triangle wave formula (was wrong → clean sine)
- Test: `test/services/metronome_audio_engine_test.dart` — 14 tests pass

### [x] Task 0.4: Delete old audio engines
- Delete `lib/services/audio/audio_engine_mobile.dart`
- Delete `lib/services/audio/audio_engine.dart`
- Keep `lib/services/audio/audio_engine_web.dart` (web is fine)
- Keep `lib/services/audio/metronome_sample_generator.dart` (used by ToneConfigNotifier)

---

## Phase 1: Core Timing Fix

### [x] Task 1.1: Rewrite FlutterMetronomePlaybackClient
- Modify `lib/providers/metronome_runtime_providers.dart` — `FlutterMetronomePlaybackClient`
- Replace `Timer.periodic` with `WallClockScheduler`
- Audio and haptic fired in parallel (both `unawaited`, not sequential)
- Add try-catch around `_handleTick` so single failure doesn't kill playback
- Dispose: `await stop()` instead of `unawaited(stop())`

### [x] Task 1.2: Wire MetronomeAudioClient to new engine
- Modify `lib/providers/metronome_runtime_providers.dart` — `AudioEngineMetronomeAudioClient`
- Replace `AudioEngine` usage with `MetronomeAudioEngine`
- Pre-warm: call `MetronomeAudioEngine.initialize()` during app startup

### [x] Task 1.3: Add drift compensation test
- Create `test/services/scheduler_drift_test.dart`
- Measure tick accuracy over 30 seconds at 120 BPM
- Assert: cumulative drift < 50ms over 30 seconds

---

## Phase 2: Haptic Fix

### [x] Task 2.1: Expand MetronomeHapticsClient interface
- Modify `lib/providers/metronome_runtime_providers.dart`
- Add `heavyClick()`, `mediumClick()`, `tick()` to `MetronomeHapticsClient`
- Implement all methods in `SystemMetronomeHapticsClient` using `HapticFeedback`
- Updated `FakeMetronomeHapticsClient` test helper

### [x] Task 2.2: Wire differentiated haptics into playback
- Accent beat → `heavyClick()`, Normal → `mediumClick()`, Subdivision → `tick()`, Silent → none
- Fire haptic and audio in parallel (both `unawaited`)

---

## Phase 3: Performance — Reduce Rebuilds

### [x] Task 3.1: Add selective provider for current beat
- Modify `lib/providers/metronome_selective_providers.dart`
- Use `ref.watch(metronomeProvider.select((s) => s.currentBeat))` instead of watching full state

### [x] Task 3.2: Fix CentralTempoCircle rebuild frequency
- Modify `lib/widgets/metronome/central_tempo_circle.dart`
- Pulse animation duration = min(200ms, intervalMs * 0.8) — never overlap

### [x] Task 3.3: Debounce rapid BPM changes
- Modify `lib/providers/metronome_provider.dart` — `setBpm()`, `rotateTempo()`
- Add 50ms debounce timer before calling `_syncPlaybackConfig()`

---

## Phase 4: UX Fixes

### [x] Task 4.1: BPM range 1-600
- Modify `lib/providers/metronome_provider.dart` — `_clampBpm()`
- Change `clamp(10, 260)` → `clamp(1, 600)`
- Updated `MetronomePlaybackConfig.interval` clamp: min 500µs

### [x] Task 4.2: Dial sensitivity fix
- Modify `lib/widgets/metronome/central_tempo_circle.dart` — `_onPanUpdate()`
- Normalize delta by device pixel ratio
- Haptic "notch" every 5 BPM via `HapticFeedback.selectionClick()`

### [x] Task 4.3: Wire AudioFocusManager
- Modify `lib/providers/metronome_provider.dart` — `start()` and `stop()`
- Call `AudioFocusManager().requestFocus()` on start
- Call `AudioFocusManager().releaseFocus()` on stop

### [x] Task 4.4: Add count-in
- Modify `lib/models/metronome_state.dart` — add `countInBars` field
- Modify `MetronomePlaybackConfig` — count-in ticks skip audio, fire haptics
- Add `_CountInSelector` UI (ChoiceChips: 0/1/2/4 bars) to metronome screen

### [x] Task 4.5: Integrate tap tempo
- Found existing `TapBPMWidget` at `lib/widgets/tap_bpm_widget.dart`
- Integrated into metronome screen layout

---

## Phase 5: Error Handling & Cleanup

### [x] Task 5.1: Add tick error recovery
- Already done in Task 1.1 — try-catch in `_handleTick()` tracks `_consecutiveErrors`

### [x] Task 5.2: Fix dispose chain
- `FlutterMetronomePlaybackClient.dispose()` calls `_scheduler.dispose()` after `stop()`
- Haptic client methods have individual try-catch for safety

### [x] Task 5.3: Delete dead code
- Delete `lib/services/audio/metronome_service.dart` (thin wrapper, confirmed unused)
- Kept `lib/services/audio/tone_generator.dart` (imported by `tuner_provider.dart`)
- Delete `lib/services/audio/audio_engine_mobile.dart` (done in Task 0.4)
- Delete `lib/services/audio/audio_engine.dart` (done in Task 0.4)
- Analyze: 0 new issues

### [x] Task 5.4: Add timing accuracy test
- Create `test/integration/metronome_timing_test.dart`
- Also created `test/services/audio/flutter_metronome_playback_client_test.dart` by subagent
- All 103 tests pass

---

## Files Changed Summary

| Action | File |
|--------|------|
| Modify | `pubspec.yaml` |
| Create | `lib/services/audio/wall_clock_scheduler.dart` |
| Create | `lib/services/audio/metronome_audio_engine.dart` |
| Modify | `lib/providers/metronome_runtime_providers.dart` |
| Modify | `lib/providers/metronome_provider.dart` |
| Modify | `lib/providers/metronome_selective_providers.dart` |
| Modify | `lib/models/metronome_state.dart` (+ .g.dart) |
| Modify | `lib/widgets/metronome/central_tempo_circle.dart` |
| Modify | `lib/screens/metronome_screen.dart` |
| Modify | `test/helpers/metronome_test_runtime.dart` |
| Modify | `test/providers/metronome_provider_test.dart` |
| Delete | `lib/services/audio/audio_engine_mobile.dart` |
| Delete | `lib/services/audio/audio_engine.dart` |
| Delete | `lib/services/audio/metronome_service.dart` |
| Create | `test/services/wall_clock_scheduler_test.dart` |
| Create | `test/services/metronome_audio_engine_test.dart` |
| Create | `test/services/scheduler_drift_test.dart` |
| Create | `test/integration/metronome_timing_test.dart` |
| Create | `test/services/audio/flutter_metronome_playback_client_test.dart` |

## Git Log
```
bb4cb8f chore: add error recovery, delete dead code, add timing test
c155fb0 feat: add AudioFocusManager, count-in, and tap tempo
99b453b feat: extend BPM range to 1-600 and fix dial sensitivity
9592de3 perf: reduce widget rebuilds, fix pulse animation, debounce BPM changes
3c847d7 feat: add drift test and differentiated haptic feedback
e581d11 feat: rewrite playback client with WallClockScheduler and new audio engine
d236cfc chore: remove old audio engine files
b210b19 feat: add low-latency MetronomeAudioEngine with flutter_soloud
246bdfb feat: add WallClockScheduler with drift compensation
27d3ab3 chore: replace audioplayers with flutter_soloud for low-latency audio
```

## Test Results
- **103 tests pass** across provider, service, and integration test suites
- **flutter analyze**: 0 new errors or warnings
- **Drift test**: WallClockScheduler cumulative drift < 3ms over 30 seconds (target: < 50ms)
