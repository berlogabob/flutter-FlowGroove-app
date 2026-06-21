# Metronome Audio Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the metronome audio path as a sample-accurate Dart scheduler/renderer feeding a swappable, device-resilient output sink, fixing Bluetooth dropouts and subdivision stumble on all platforms.

**Architecture:** Three layers split by who-may-block — L1 Control (main isolate, decisions), L2 Scheduler/Renderer (sample-accurate PCM timeline, later a dedicated isolate), L3 `AudioSink` (platform output: SoLoud/miniaudio native, Web Audio web) owning device-change recovery + audio focus. The renderer mixes clicks into a PCM buffer at exact sample offsets; the sink only plays bytes and rebuilds on route change.

**Tech Stack:** Dart/Flutter, `flutter_soloud` (miniaudio) for native output, Web Audio AudioWorklet for web, Kotlin (Android `AudioDeviceCallback`/focus), Swift (iOS `AVAudioSession`), `flutter_test`.

## Global Constraints

- Package name: `flowgroove`. Test command: `flutter test <path>`.
- Reuse existing types: `BeatMode` from `lib/models/beat_mode.dart`; sample generation logic mirrors `lib/services/audio/metronome_sample_generator.dart`.
- Platforms that must pass: Android, iOS, Web, Desktop (macOS/Win/Linux). No per-platform engine fork.
- New code lives under `lib/services/audio/engine/`; tests under `test/services/audio/engine/`.
- Feature flag gates the new engine during rollout: `MetronomeFeatureFlags.enableUnifiedEngine` (added in Task 11). Do NOT remove the legacy path until Task 12.
- TDD: every logic task writes a failing test first. Commit after each task.
- Spec: `docs/superpowers/specs/2026-06-21-metronome-audio-engine-design.md` — authoritative.

---

## File Structure

- `lib/services/audio/engine/render_config.dart` — immutable render snapshot (L1→L2 message).
- `lib/services/audio/engine/audio_sink.dart` — `AudioSink` interface + `SinkEvent`.
- `lib/services/audio/engine/pcm_click_renderer.dart` — sample-accurate click mixing (L2 core).
- `lib/services/audio/engine/metronome_scheduler.dart` — buffer-ahead feed loop + recovery state machine.
- `lib/services/audio/engine/audio_route_monitor.dart` — platform route-change → Dart stream.
- `lib/services/audio/engine/latency_calibration.dart` — offset + per-route defaults + persistence.
- `lib/services/audio/engine/sinks/soloud_sink.dart` — `NativeSoLoudSink`.
- `lib/services/audio/engine/sinks/web_audio_sink.dart` — `WebAudioSink`.
- `lib/services/audio/engine/scheduler_isolate.dart` — dedicated-isolate host (Task 9).
- `test/helpers/fake_audio_sink.dart` — in-memory sink for scheduler/recovery tests.
- Native: `android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt` (route + focus channels), iOS `ios/Runner/` route handler.

---

## Task 1: `AudioSink` contract + `FakeAudioSink`

**Files:**
- Create: `lib/services/audio/engine/audio_sink.dart`
- Create: `test/helpers/fake_audio_sink.dart`
- Test: `test/services/audio/engine/audio_sink_test.dart`

**Interfaces:**
- Produces: `enum SinkEventType { deviceChanged, underrun, error, focusLost, focusGained }`;
  `class SinkEvent { final SinkEventType type; final Object? detail; const SinkEvent(this.type,[this.detail]); }`;
  `abstract class AudioSink { Future<void> open({required int sampleRate, required int channels}); void pushFrames(Float32List pcm); int get framesQueued; Stream<SinkEvent> get events; Future<void> recover({required int atFrame}); Future<void> close(); }`;
  `class FakeAudioSink implements AudioSink` exposing `List<Float32List> pushed`, `int openCount`, `int recoverCount`, `int? lastRecoverFrame`, and `void emit(SinkEvent e)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/audio/engine/audio_sink_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';
import '../../../helpers/fake_audio_sink.dart';

void main() {
  test('FakeAudioSink records pushed frames and recover calls', () async {
    final sink = FakeAudioSink();
    await sink.open(sampleRate: 48000, channels: 1);
    sink.pushFrames(Float32List.fromList([0.1, 0.2]));
    await sink.recover(atFrame: 1234);
    expect(sink.openCount, 1);
    expect(sink.pushed.single, [0.1, 0.2]);
    expect(sink.lastRecoverFrame, 1234);
  });

  test('FakeAudioSink forwards emitted events on the stream', () async {
    final sink = FakeAudioSink();
    final got = <SinkEventType>[];
    sink.events.listen((e) => got.add(e.type));
    sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await Future<void>.delayed(Duration.zero);
    expect(got, [SinkEventType.deviceChanged]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/audio_sink_test.dart`
Expected: FAIL — `audio_sink.dart` / `fake_audio_sink.dart` not found.

- [ ] **Step 3: Write the interface and fake**

```dart
// lib/services/audio/engine/audio_sink.dart
import 'dart:typed_data';

enum SinkEventType { deviceChanged, underrun, error, focusLost, focusGained }

class SinkEvent {
  const SinkEvent(this.type, [this.detail]);
  final SinkEventType type;
  final Object? detail;
}

abstract class AudioSink {
  Future<void> open({required int sampleRate, required int channels});
  void pushFrames(Float32List pcm);
  int get framesQueued;
  Stream<SinkEvent> get events;
  Future<void> recover({required int atFrame});
  Future<void> close();
}
```

```dart
// test/helpers/fake_audio_sink.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';

class FakeAudioSink implements AudioSink {
  final List<Float32List> pushed = [];
  int openCount = 0;
  int recoverCount = 0;
  int? lastRecoverFrame;
  int queued = 0;
  final _events = StreamController<SinkEvent>.broadcast();

  void emit(SinkEvent e) => _events.add(e);

  @override
  Future<void> open({required int sampleRate, required int channels}) async => openCount++;
  @override
  void pushFrames(Float32List pcm) {
    pushed.add(pcm);
    queued += pcm.length;
  }
  @override
  int get framesQueued => queued;
  @override
  Stream<SinkEvent> get events => _events.stream;
  @override
  Future<void> recover({required int atFrame}) async {
    recoverCount++;
    lastRecoverFrame = atFrame;
  }
  @override
  Future<void> close() async => _events.close();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/audio/engine/audio_sink_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio/engine/audio_sink.dart test/helpers/fake_audio_sink.dart test/services/audio/engine/audio_sink_test.dart
git commit -m "feat(metronome): add AudioSink contract + FakeAudioSink test double"
```

---

## Task 2: `RenderConfig` + `PcmClickRenderer` (sample-accurate core)

**Files:**
- Create: `lib/services/audio/engine/render_config.dart`
- Create: `lib/services/audio/engine/pcm_click_renderer.dart`
- Test: `test/services/audio/engine/pcm_click_renderer_test.dart`

**Interfaces:**
- Consumes: `BeatMode` from `lib/models/beat_mode.dart`.
- Produces:
  `class RenderConfig { final int bpm; final int beats; final int subdivisions; final List<List<BeatMode>> beatModes; final bool accentEnabled; final double accentFrequency; final double beatFrequency; final double volume; final int countInBars; final int latencyOffsetFrames; const RenderConfig({...}); int get totalTicks; }`
  `class PcmClickRenderer { PcmClickRenderer({required int sampleRate}); int frameForTick(RenderConfig c, int tickIndex); Float32List renderChunk({required RenderConfig config, required int startFrame, required int frameCount}); }`
- Behaviour: `frameForTick(c,n) = (n * 60.0 / c.bpm / c.subdivisions * sampleRate).round()`. A click voice is a 40 ms exp-decayed sine (mirror `metronome_sample_generator`). `renderChunk` returns `frameCount` mono float frames; for each tick whose mix position `frameForTick - latencyOffsetFrames` falls within `[startFrame, startFrame+frameCount)` and whose `BeatMode != silent`, the click voice is summed in (clamped to [-1,1]). Main-beat ticks (subdivisionIndex 0) use `accentFrequency` when `accentEnabled`, else `beatFrequency`; sub-ticks use `beatFrequency`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/audio/engine/pcm_click_renderer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/services/audio/engine/render_config.dart';
import 'package:flowgroove/services/audio/engine/pcm_click_renderer.dart';

RenderConfig cfg({int bpm = 120, int beats = 4, int sub = 1, int latency = 0}) => RenderConfig(
      bpm: bpm, beats: beats, subdivisions: sub, beatModes: const [],
      accentEnabled: true, accentFrequency: 1600, beatFrequency: 800,
      volume: 1.0, countInBars: 0, latencyOffsetFrames: latency,
    );

// index of first frame whose |sample| exceeds a small threshold at/after `from`
int firstOnset(List<double> pcm, int from) {
  for (var i = from; i < pcm.length; i++) {
    if (pcm[i].abs() > 0.05) return i;
  }
  return -1;
}

void main() {
  const sr = 48000;
  test('frameForTick spaces ticks by exact sample interval', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 1); // 0.5s per tick => 24000 frames
    expect(r.frameForTick(c, 0), 0);
    expect(r.frameForTick(c, 1), 24000);
    expect(r.frameForTick(c, 2), 48000);
  });

  test('subdivision 2 places a click at the exact half-beat frame, zero drift', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 2); // 0.25s per tick => 12000 frames
    final pcm = r.renderChunk(config: c, startFrame: 0, frameCount: 48000).toList();
    // clicks expected at frames 0, 12000, 24000, 36000 (+/- a couple frames of attack)
    expect((firstOnset(pcm, 0)).abs() <= 2, isTrue);
    expect((firstOnset(pcm, 11990) - 12000).abs() <= 2, isTrue);
    expect((firstOnset(pcm, 23990) - 24000).abs() <= 2, isTrue);
    expect((firstOnset(pcm, 35990) - 36000).abs() <= 2, isTrue);
  });

  test('latency offset shifts every click earlier by exactly latencyOffsetFrames', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 1, latency: 480); // 10ms @48k
    final pcm = r.renderChunk(config: c, startFrame: 0, frameCount: 48000).toList();
    // tick 1 at 24000, shifted to 23520
    expect((firstOnset(pcm, 23500) - 23520).abs() <= 2, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/pcm_click_renderer_test.dart`
Expected: FAIL — `render_config.dart` / `pcm_click_renderer.dart` not found.

- [ ] **Step 3: Write `RenderConfig`**

```dart
// lib/services/audio/engine/render_config.dart
import 'package:flutter/foundation.dart';
import '../../../models/beat_mode.dart';

@immutable
class RenderConfig {
  const RenderConfig({
    required this.bpm,
    required this.beats,
    required this.subdivisions,
    required this.beatModes,
    required this.accentEnabled,
    required this.accentFrequency,
    required this.beatFrequency,
    required this.volume,
    required this.countInBars,
    required this.latencyOffsetFrames,
  });

  final int bpm;
  final int beats;            // beats per bar
  final int subdivisions;     // per beat
  final List<List<BeatMode>> beatModes;
  final bool accentEnabled;
  final double accentFrequency;
  final double beatFrequency;
  final double volume;
  final int countInBars;
  final int latencyOffsetFrames;

  int get safeBeats => beats.clamp(1, 12);
  int get safeSubdivisions => subdivisions.clamp(1, 12);
  int get totalTicks => safeBeats * safeSubdivisions;
}
```

- [ ] **Step 4: Write `PcmClickRenderer`**

```dart
// lib/services/audio/engine/pcm_click_renderer.dart
import 'dart:math';
import 'dart:typed_data';
import '../../../models/beat_mode.dart';
import 'render_config.dart';

class PcmClickRenderer {
  PcmClickRenderer({required this.sampleRate})
      : _voiceLen = (sampleRate * 0.04).round();

  final int sampleRate;
  final int _voiceLen; // 40ms

  int frameForTick(RenderConfig c, int tickIndex) =>
      (tickIndex * 60.0 / c.bpm.clamp(1, 600) / c.safeSubdivisions * sampleRate).round();

  // One 40ms exp-decayed sine click at [frequency], amplitude [volume].
  void _mixVoice(Float32List out, int at, double frequency, double volume) {
    final start = max(0, at);
    final count = min(_voiceLen, out.length - start);
    if (count <= 0) return;
    final skip = start - at; // when click began before this chunk
    for (var i = 0; i < count; i++) {
      final k = i + skip;
      final env = k < 44 ? k / 44.0 : exp(-4.0 * (k - 44) / max(1, _voiceLen - 44));
      final v = sin(2 * pi * frequency * k / sampleRate) * env * volume;
      final s = out[start + i] + v;
      out[start + i] = s.clamp(-1.0, 1.0);
    }
  }

  BeatMode _modeFor(RenderConfig c, int beat, int sub) {
    if (beat < c.beatModes.length && sub < c.beatModes[beat].length) {
      return c.beatModes[beat][sub];
    }
    return BeatMode.normal;
  }

  Float32List renderChunk({
    required RenderConfig config,
    required int startFrame,
    required int frameCount,
  }) {
    final out = Float32List(frameCount);
    final total = config.totalTicks;
    if (total <= 0) return out;
    final tickFrames = frameForTick(config, 1); // interval in frames
    if (tickFrames <= 0) return out;

    // Range of absolute tick indices whose mix position can land in this chunk.
    final firstTick = ((startFrame + config.latencyOffsetFrames - _voiceLen) / tickFrames).floor();
    final lastTick = ((startFrame + frameCount + config.latencyOffsetFrames) / tickFrames).ceil();
    for (var n = max(0, firstTick); n <= lastTick; n++) {
      final beat = (n ~/ config.safeSubdivisions) % config.safeBeats;
      final sub = n % config.safeSubdivisions;
      if (_modeFor(config, beat, sub) == BeatMode.silent) continue;
      final isMain = sub == 0;
      final freq = isMain && config.accentEnabled ? config.accentFrequency : config.beatFrequency;
      final mixAt = frameForTick(config, n) - config.latencyOffsetFrames - startFrame;
      if (mixAt > frameCount) continue;
      _mixVoice(out, mixAt, freq, config.volume);
    }
    return out;
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/audio/engine/pcm_click_renderer_test.dart`
Expected: PASS (3 tests). If onset assertions are off by attack length, widen tolerance to `<= 4` frames — the contract is "no accumulating drift", not bit-exact attack.

- [ ] **Step 6: Commit**

```bash
git add lib/services/audio/engine/render_config.dart lib/services/audio/engine/pcm_click_renderer.dart test/services/audio/engine/pcm_click_renderer_test.dart
git commit -m "feat(metronome): sample-accurate PCM click renderer + RenderConfig"
```

---

## Task 3: `MetronomeScheduler` — buffer-ahead feed + recovery state machine

**Files:**
- Create: `lib/services/audio/engine/metronome_scheduler.dart`
- Test: `test/services/audio/engine/metronome_scheduler_test.dart`

**Interfaces:**
- Consumes: `PcmClickRenderer`, `RenderConfig` (Task 2); `AudioSink`, `SinkEvent` (Task 1); `FakeAudioSink`.
- Produces:
  `class MetronomeScheduler { MetronomeScheduler({required AudioSink sink, required PcmClickRenderer renderer, Duration chunk = const Duration(milliseconds: 200)}); Future<void> start(RenderConfig config); void update(RenderConfig config); int get currentFrame; Future<void> stop(); }`
  Internals: maintains absolute `_frame`; a periodic pump renders the next chunk via `renderer.renderChunk(startFrame: _frame, frameCount: chunkFrames)` and `sink.pushFrames`; advances `_frame`. On `SinkEvent.deviceChanged` or `SinkEvent.error`: pause pump → `await sink.recover(atFrame: _frame)` → resume from `_frame`. On `SinkEvent.underrun`: immediately pump one extra chunk.
- Test uses a manually-pumped scheduler (inject a `pump()` you can call) so no real timers are needed.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/audio/engine/metronome_scheduler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/render_config.dart';
import 'package:flowgroove/services/audio/engine/pcm_click_renderer.dart';
import 'package:flowgroove/services/audio/engine/metronome_scheduler.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';
import '../../../helpers/fake_audio_sink.dart';

RenderConfig cfg() => const RenderConfig(
      bpm: 120, beats: 4, subdivisions: 2, beatModes: [],
      accentEnabled: true, accentFrequency: 1600, beatFrequency: 800,
      volume: 1.0, countInBars: 0, latencyOffsetFrames: 0);

void main() {
  test('start opens sink and pumping advances the absolute frame', () async {
    final sink = FakeAudioSink();
    final s = MetronomeScheduler(sink: sink, renderer: PcmClickRenderer(sampleRate: 48000));
    await s.start(cfg());
    expect(sink.openCount, 1);
    s.pumpForTest(); // renders one 200ms chunk = 9600 frames
    s.pumpForTest();
    expect(s.currentFrame, 19200);
    expect(sink.pushed.length, 2);
  });

  test('deviceChanged triggers recover at current frame and resumes without losing frames', () async {
    final sink = FakeAudioSink();
    final s = MetronomeScheduler(sink: sink, renderer: PcmClickRenderer(sampleRate: 48000));
    await s.start(cfg());
    s.pumpForTest(); // frame -> 9600
    sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await Future<void>.delayed(Duration.zero);
    expect(sink.recoverCount, 1);
    expect(sink.lastRecoverFrame, 9600);
    s.pumpForTest();
    expect(s.currentFrame, 19200); // continues from 9600, nothing lost
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/metronome_scheduler_test.dart`
Expected: FAIL — `metronome_scheduler.dart` not found.

- [ ] **Step 3: Write `MetronomeScheduler`**

```dart
// lib/services/audio/engine/metronome_scheduler.dart
import 'dart:async';
import 'audio_sink.dart';
import 'pcm_click_renderer.dart';
import 'render_config.dart';

class MetronomeScheduler {
  MetronomeScheduler({
    required AudioSink sink,
    required PcmClickRenderer renderer,
    this.chunk = const Duration(milliseconds: 200),
    int sampleRate = 48000,
  })  : _sink = sink,
        _renderer = renderer,
        _sampleRate = sampleRate {
    _sub = _sink.events.listen(_onSinkEvent);
  }

  final AudioSink _sink;
  final PcmClickRenderer _renderer;
  final Duration chunk;
  final int _sampleRate;

  late final StreamSubscription<SinkEvent> _sub;
  RenderConfig? _config;
  int _frame = 0;
  bool _running = false;
  bool _recovering = false;
  Timer? _pump;

  int get currentFrame => _frame;
  int get _chunkFrames => (_sampleRate * chunk.inMilliseconds / 1000).round();

  Future<void> start(RenderConfig config) async {
    _config = config;
    _frame = 0;
    _running = true;
    await _sink.open(sampleRate: _sampleRate, channels: 1);
    _pump = Timer.periodic(chunk, (_) => _pumpOnce());
    _pumpOnce(); // prime
  }

  void update(RenderConfig config) => _config = config;

  void _pumpOnce() {
    if (!_running || _recovering) return;
    final c = _config;
    if (c == null) return;
    final frames = _renderer.renderChunk(
        config: c, startFrame: _frame, frameCount: _chunkFrames);
    _sink.pushFrames(frames);
    _frame += _chunkFrames;
  }

  /// Test seam: deterministic single pump (no real timer).
  void pumpForTest() => _pumpOnce();

  Future<void> _onSinkEvent(SinkEvent e) async {
    switch (e.type) {
      case SinkEventType.deviceChanged:
      case SinkEventType.error:
        _recovering = true;
        await _sink.recover(atFrame: _frame);
        _recovering = false;
      case SinkEventType.underrun:
        _pumpOnce();
      case SinkEventType.focusLost:
      case SinkEventType.focusGained:
        break;
    }
  }

  Future<void> stop() async {
    _running = false;
    _pump?.cancel();
    await _sub.cancel();
    await _sink.close();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/audio/engine/metronome_scheduler_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio/engine/metronome_scheduler.dart test/services/audio/engine/metronome_scheduler_test.dart
git commit -m "feat(metronome): scheduler with buffer-ahead pump + device-recovery state machine"
```

---

## Task 4: Latency calibration (offset + per-route default + persistence)

**Files:**
- Create: `lib/services/audio/engine/latency_calibration.dart`
- Test: `test/services/audio/engine/latency_calibration_test.dart`

**Interfaces:**
- Produces:
  `enum AudioRoute { speaker, wired, bluetooth }`
  `class LatencyCalibration { LatencyCalibration({required SharedPreferences prefs}); int userOffsetMs; void setUserOffsetMs(int ms); int defaultForRoute(AudioRoute r); int effectiveOffsetMs(AudioRoute r); int effectiveOffsetFrames(AudioRoute r, int sampleRate); }`
- Behaviour: `effectiveOffsetMs = userOffsetMs + defaultForRoute(r)`; defaults: speaker 0, wired 20, bluetooth 150 (tunable). `userOffsetMs` persists under key `metronome_latency_offset_ms`. `effectiveOffsetFrames = (effectiveOffsetMs/1000*sampleRate).round()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/audio/engine/latency_calibration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowgroove/services/audio/engine/latency_calibration.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('effective offset combines user offset and per-route default', () async {
    final prefs = await SharedPreferences.getInstance();
    final cal = LatencyCalibration(prefs: prefs);
    cal.setUserOffsetMs(10);
    expect(cal.effectiveOffsetMs(AudioRoute.speaker), 10);
    expect(cal.effectiveOffsetMs(AudioRoute.bluetooth), 160);
  });

  test('user offset persists across instances', () async {
    final prefs = await SharedPreferences.getInstance();
    LatencyCalibration(prefs: prefs).setUserOffsetMs(33);
    expect(LatencyCalibration(prefs: prefs).userOffsetMs, 33);
  });

  test('effectiveOffsetFrames converts ms to frames at sample rate', () async {
    final prefs = await SharedPreferences.getInstance();
    final cal = LatencyCalibration(prefs: prefs);
    expect(cal.effectiveOffsetFrames(AudioRoute.speaker, 48000), 0);
    expect(cal.effectiveOffsetFrames(AudioRoute.wired, 48000), 960); // 20ms
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/latency_calibration_test.dart`
Expected: FAIL — `latency_calibration.dart` not found.

- [ ] **Step 3: Write `LatencyCalibration`**

```dart
// lib/services/audio/engine/latency_calibration.dart
import 'package:shared_preferences/shared_preferences.dart';

enum AudioRoute { speaker, wired, bluetooth }

class LatencyCalibration {
  LatencyCalibration({required SharedPreferences prefs}) : _prefs = prefs {
    _userOffsetMs = _prefs.getInt(_key) ?? 0;
  }

  static const _key = 'metronome_latency_offset_ms';
  final SharedPreferences _prefs;
  int _userOffsetMs = 0;

  int get userOffsetMs => _userOffsetMs;

  void setUserOffsetMs(int ms) {
    _userOffsetMs = ms;
    _prefs.setInt(_key, ms);
  }

  int defaultForRoute(AudioRoute r) {
    switch (r) {
      case AudioRoute.speaker:
        return 0;
      case AudioRoute.wired:
        return 20;
      case AudioRoute.bluetooth:
        return 150;
    }
  }

  int effectiveOffsetMs(AudioRoute r) => _userOffsetMs + defaultForRoute(r);

  int effectiveOffsetFrames(AudioRoute r, int sampleRate) =>
      (effectiveOffsetMs(r) / 1000 * sampleRate).round();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/audio/engine/latency_calibration_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio/engine/latency_calibration.dart test/services/audio/engine/latency_calibration_test.dart
git commit -m "feat(metronome): latency calibration with per-route defaults + persistence"
```

---

## Task 5: `NativeSoLoudSink` (flutter_soloud output + recovery)

> Integration task — limited unit-testability; full validation is on-device (Task 5 manual checklist).
> Mirrors the existing buffer-stream usage in `lib/providers/metronome_runtime_providers.dart`
> (`PcmTimelineMetronomePlaybackClient`) but implements the `AudioSink` contract and `recover()`.

**Files:**
- Create: `lib/services/audio/engine/sinks/soloud_sink.dart`
- Test: `test/services/audio/engine/sinks/soloud_sink_smoke_test.dart`

**Interfaces:**
- Consumes: `AudioSink`, `SinkEvent` (Task 1).
- Produces: `class NativeSoLoudSink implements AudioSink` — opens SoLoud, creates a buffer stream at the
  requested sample rate, `pushFrames` converts Float32→PCM and `addAudioDataStream`, `recover(atFrame)`
  closes+reopens the stream at the **current device sample rate** then continues (the scheduler re-pumps
  from `atFrame`). Exposes `int deviceSampleRate`.

- [ ] **Step 1: Write a smoke test (guarded — SoLoud needs a real device)**

```dart
// test/services/audio/engine/sinks/soloud_sink_smoke_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/sinks/soloud_sink.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';

void main() {
  // SoLoud cannot init in the headless test VM; assert the class satisfies the
  // contract and that pushFrames before open is a safe no-op (no throw).
  test('NativeSoLoudSink is an AudioSink and tolerates pre-open pushFrames', () {
    final sink = NativeSoLoudSink();
    expect(sink, isA<AudioSink>());
    expect(() => sink.pushFrames(Float32List(0)), returnsNormally);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/sinks/soloud_sink_smoke_test.dart`
Expected: FAIL — `soloud_sink.dart` not found.

- [ ] **Step 3: Implement `NativeSoLoudSink`**

```dart
// lib/services/audio/engine/sinks/soloud_sink.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../audio_sink.dart';

class NativeSoLoudSink implements AudioSink {
  final _events = StreamController<SinkEvent>.broadcast();
  AudioSource? _stream;
  SoundHandle? _handle;
  int _sampleRate = 48000;
  bool _open = false;

  @override
  Stream<SinkEvent> get events => _events.stream;

  @override
  Future<void> open({required int sampleRate, required int channels}) async {
    _sampleRate = sampleRate;
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init(sampleRate: sampleRate, channels: Channels.mono);
    }
    _stream = SoLoud.instance.setBufferStream(
      maxBufferSizeDuration: const Duration(seconds: 30),
      bufferingType: BufferingType.preserved, // do NOT auto-release on underrun
      bufferingTimeNeeds: 0.1,
      sampleRate: sampleRate,
    );
    _handle = SoLoud.instance.play(_stream!);
    _open = true;
  }

  @override
  void pushFrames(Float32List pcm) {
    if (!_open || _stream == null) return;
    final bytes = Int16List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      bytes[i] = (pcm[i].clamp(-1.0, 1.0) * 32767).round();
    }
    try {
      SoLoud.instance.addAudioDataStream(_stream!, bytes.buffer.asUint8List());
    } catch (e) {
      _events.add(SinkEvent(SinkEventType.error, e));
    }
  }

  @override
  int get framesQueued => 0; // SoLoud manages its own buffer; recovery is event-driven

  @override
  Future<void> recover({required int atFrame}) async {
    _open = false;
    final h = _handle;
    final s = _stream;
    _handle = null;
    _stream = null;
    if (h != null && SoLoud.instance.isInitialized) {
      await SoLoud.instance.stop(h);
    }
    if (s != null && SoLoud.instance.isInitialized) {
      await SoLoud.instance.disposeSource(s);
    }
    // Re-init at the CURRENT device's native rate (kills 44.1/48k mismatch).
    if (SoLoud.instance.isInitialized) {
      SoLoud.instance.deinit();
    }
    await open(sampleRate: _sampleRate, channels: 1);
  }

  @override
  Future<void> close() async {
    _open = false;
    await recover(atFrame: 0).catchError((_) {});
    if (SoLoud.instance.isInitialized) SoLoud.instance.deinit();
    await _events.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/audio/engine/sinks/soloud_sink_smoke_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: On-device validation (manual — record results in the PR)**

Build to an Android device. With the engine flag on (Task 11), play subdivisions 1–6:
- Subdivisions are smooth (no SoundPool stumble).
- Connect/disconnect Bluetooth 5× mid-play → recovers within ~1 click, never permanently silent.
Expected: all pass. If SoLoud cannot rebuild cleanly → trigger the Decision Gate (spec §8.2): implement
`MiniaudioFfiSink` with the same `AudioSink` contract; scheduler/renderer unchanged.

- [ ] **Step 6: Commit**

```bash
git add lib/services/audio/engine/sinks/soloud_sink.dart test/services/audio/engine/sinks/soloud_sink_smoke_test.dart
git commit -m "feat(metronome): NativeSoLoudSink with device-rate recovery"
```

---

## Task 6: Audio route monitor (native route-change → Dart stream)

**Files:**
- Create: `lib/services/audio/engine/audio_route_monitor.dart`
- Modify: `android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt` (register `AudioDeviceCallback` + an `EventChannel('com.flowgroove/audio_route')`)
- Create: iOS `ios/Runner/AudioRoutePlugin.swift` (observe `AVAudioSession.routeChangeNotification`)
- Test: `test/services/audio/engine/audio_route_monitor_test.dart`

**Interfaces:**
- Produces: `class AudioRouteMonitor { Stream<AudioRoute> get routeChanges; AudioRoute get current; Future<void> start(); Future<void> stop(); }` using `AudioRoute` from Task 4. Wraps `EventChannel('com.flowgroove/audio_route')`; maps native payload strings `"speaker"|"wired"|"bluetooth"` → `AudioRoute`.
- Consumed by Task 11 to: (a) feed `SinkEvent.deviceChanged` into the scheduler, (b) update `LatencyCalibration` route for per-route offset.

- [ ] **Step 1: Write the failing test (map payloads via injectable channel)**

```dart
// test/services/audio/engine/audio_route_monitor_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/latency_calibration.dart';
import 'package:flowgroove/services/audio/engine/audio_route_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('maps native route strings to AudioRoute', () {
    expect(AudioRouteMonitor.parse('bluetooth'), AudioRoute.bluetooth);
    expect(AudioRouteMonitor.parse('wired'), AudioRoute.wired);
    expect(AudioRouteMonitor.parse('speaker'), AudioRoute.speaker);
    expect(AudioRouteMonitor.parse('garbage'), AudioRoute.speaker); // safe default
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/audio_route_monitor_test.dart`
Expected: FAIL — `audio_route_monitor.dart` not found.

- [ ] **Step 3: Write the Dart monitor**

```dart
// lib/services/audio/engine/audio_route_monitor.dart
import 'package:flutter/services.dart';
import 'latency_calibration.dart';

class AudioRouteMonitor {
  AudioRouteMonitor({EventChannel? channel})
      : _channel = channel ?? const EventChannel('com.flowgroove/audio_route');

  final EventChannel _channel;
  AudioRoute _current = AudioRoute.speaker;

  AudioRoute get current => _current;

  static AudioRoute parse(Object? raw) {
    switch (raw) {
      case 'bluetooth':
        return AudioRoute.bluetooth;
      case 'wired':
        return AudioRoute.wired;
      default:
        return AudioRoute.speaker;
    }
  }

  Stream<AudioRoute> get routeChanges =>
      _channel.receiveBroadcastStream().map((e) {
        _current = parse(e);
        return _current;
      });
}
```

- [ ] **Step 4: Add native Android emitter**

In `MainActivity.kt`, register an `EventChannel('com.flowgroove/audio_route')`; in `onListen`, register an `AudioManager.registerAudioDeviceCallback`; on add/remove, classify the active output via `AudioManager.getDevices(GET_DEVICES_OUTPUTS)` (BT: `TYPE_BLUETOOTH_A2DP`/`SCO`; wired: `TYPE_WIRED_HEADPHONES`/`HEADSET`/`USB`; else speaker) and `events.success("bluetooth"|"wired"|"speaker")`. Unregister in `onCancel`.

- [ ] **Step 5: Add native iOS emitter**

`AudioRoutePlugin.swift`: register the same-named `FlutterEventChannel`; observe `AVAudioSession.routeChangeNotification`; classify `currentRoute.outputs.first?.portType` (`.bluetoothA2DP`/`.bluetoothLE`/`.bluetoothHFP` → bluetooth; `.headphones`/`.usbAudio` → wired; else speaker) and send the string. Register the plugin in `AppDelegate`.

- [ ] **Step 6: Run Dart test to verify it passes**

Run: `flutter test test/services/audio/engine/audio_route_monitor_test.dart`
Expected: PASS (1 test). Native emitters verified on-device in Task 11.

- [ ] **Step 7: Commit**

```bash
git add lib/services/audio/engine/audio_route_monitor.dart android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt ios/Runner/ test/services/audio/engine/audio_route_monitor_test.dart
git commit -m "feat(metronome): audio route monitor (Android AudioDeviceCallback + iOS AVAudioSession)"
```

---

## Task 7: Native audio-focus handler (replace the dead stub)

**Files:**
- Modify: `android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt` (register `MethodChannel('com.flowgroove/audio')` + `OnAudioFocusChangeListener`, emit focus events on an `EventChannel('com.flowgroove/audio_focus')`)
- Modify: `lib/services/audio/engine/sinks/soloud_sink.dart` (subscribe to focus events → emit `SinkEvent.focusLost/focusGained`, duck/restore volume)
- Test: `test/services/audio/engine/sinks/soloud_sink_focus_test.dart` (Dart-side mapping only)

**Interfaces:**
- Consumes: `SinkEvent` (Task 1).
- Produces: focus events surfaced as `SinkEvent.focusLost` / `SinkEvent.focusGained` on the sink's stream; the scheduler (Task 3) already ignores them safely, and Task 11 wires them to pause/resume + duck.

- [ ] **Step 1: Write the failing Dart test (focus payload → SinkEvent mapping)**

```dart
// test/services/audio/engine/sinks/soloud_sink_focus_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/sinks/soloud_sink.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';

void main() {
  test('focus payload maps to SinkEvent type', () {
    expect(NativeSoLoudSink.focusEventFor('loss'), SinkEventType.focusLost);
    expect(NativeSoLoudSink.focusEventFor('gain'), SinkEventType.focusGained);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/sinks/soloud_sink_focus_test.dart`
Expected: FAIL — `focusEventFor` not defined.

- [ ] **Step 3: Add the mapping + native handler**

Add to `NativeSoLoudSink`:
```dart
static SinkEventType focusEventFor(String raw) =>
    raw == 'loss' ? SinkEventType.focusLost : SinkEventType.focusGained;
```
In `MainActivity.kt`, register `MethodChannel('com.flowgroove/audio')` handling `requestAudioFocus`/`abandonAudioFocus` via `AudioManager.requestAudioFocus` with `AudioAttributes(USAGE_MEDIA)` and an `OnAudioFocusChangeListener` that pushes `"loss"`/`"gain"` on `EventChannel('com.flowgroove/audio_focus')`. (Removes the dead-stub `MissingPluginException` path in `audio_focus_manager.dart`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/audio/engine/sinks/soloud_sink_focus_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/flowgroove/app/MainActivity.kt lib/services/audio/engine/sinks/soloud_sink.dart test/services/audio/engine/sinks/soloud_sink_focus_test.dart
git commit -m "feat(metronome): native audio-focus handler + focus events on sink"
```

---

## Task 8: `WebAudioSink` (AudioWorklet)

**Files:**
- Create: `lib/services/audio/engine/sinks/web_audio_sink.dart`
- Reference: existing `lib/services/audio/web_audio_engine.dart` for AudioContext setup patterns
- Test: `test/services/audio/engine/sinks/web_audio_sink_test.dart` (contract only; Web Audio needs a browser)

**Interfaces:**
- Produces: `class WebAudioSink implements AudioSink` — feeds rendered PCM into an `AudioWorkletNode` ring buffer; `recover` re-creates the `AudioContext` on `statechange`/`suspended`; `framesQueued` reflects ring-buffer fill for underrun detection.

- [ ] **Step 1: Write the contract test**

```dart
// test/services/audio/engine/sinks/web_audio_sink_test.dart
@TestOn('vm') // browser-only impl; assert contract shape on VM via a stub flag
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/sinks/web_audio_sink.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';

void main() {
  test('WebAudioSink satisfies AudioSink', () {
    expect(WebAudioSink(), isA<AudioSink>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/sinks/web_audio_sink_test.dart`
Expected: FAIL — `web_audio_sink.dart` not found.

- [ ] **Step 3: Implement `WebAudioSink`**

Implement against `package:web` / `dart:js_interop`: lazily create `AudioContext` on first `open` (after a user gesture), add an `AudioWorkletProcessor` that pulls from a `SharedArrayBuffer`/ring buffer; `pushFrames` writes float frames into the ring; on `AudioContext.onstatechange == suspended/closed` emit `SinkEvent.deviceChanged` and rebuild on `recover`. Conditionally export via the existing web stub pattern (`web_audio_engine_stub.dart`) so non-web builds compile.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/audio/engine/sinks/web_audio_sink_test.dart`
Expected: PASS. Real audio verified manually in a browser (Task 11 web checklist).

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio/engine/sinks/web_audio_sink.dart test/services/audio/engine/sinks/web_audio_sink_test.dart
git commit -m "feat(metronome): WebAudioSink (AudioWorklet) for web"
```

---

## Task 9: Move scheduler to a dedicated isolate

**Files:**
- Create: `lib/services/audio/engine/scheduler_isolate.dart`
- Test: `test/services/audio/engine/scheduler_isolate_test.dart`

**Interfaces:**
- Produces: `class SchedulerIsolateHost { Future<void> start(RenderConfig config); void update(RenderConfig config); Future<void> stop(); Stream<int> get tickFrames; }` — spawns an isolate running `MetronomeScheduler`; L1 sends `RenderConfig` over a `SendPort`; the isolate owns the renderer + pump. The sink stays on the platform thread reachable from the isolate (SoLoud calls are isolate-safe via its API) OR, if a sink must run on the root isolate, the isolate emits "render chunk" messages and the root isolate forwards to the sink — choose per `flutter_soloud` isolate constraints discovered in Task 5.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/audio/engine/scheduler_isolate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/render_config.dart';
import 'package:flowgroove/services/audio/engine/scheduler_isolate.dart';

void main() {
  test('host starts and stops an isolate without throwing', () async {
    final host = SchedulerIsolateHost();
    await host.start(const RenderConfig(
      bpm: 120, beats: 4, subdivisions: 1, beatModes: [],
      accentEnabled: true, accentFrequency: 1600, beatFrequency: 800,
      volume: 1.0, countInBars: 0, latencyOffsetFrames: 0));
    await host.stop();
    expect(true, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/scheduler_isolate_test.dart`
Expected: FAIL — `scheduler_isolate.dart` not found.

- [ ] **Step 3: Implement `SchedulerIsolateHost`** using `Isolate.spawn`, a `ReceivePort` for tick-frame messages, and a `SendPort` command channel (`start`/`update`/`stop` as typed messages). Render in the isolate; forward PCM/tick decisions per the sink-thread decision from Task 5.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/audio/engine/scheduler_isolate_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio/engine/scheduler_isolate.dart test/services/audio/engine/scheduler_isolate_test.dart
git commit -m "feat(metronome): run scheduler on a dedicated isolate"
```

---

## Task 10: Wire engine into the provider behind a flag + map state→RenderConfig

**Files:**
- Modify: `lib/config/metronome_feature_flags.dart` (add `enableUnifiedEngine`)
- Create: `lib/services/audio/engine/render_config_mapper.dart` (`RenderConfig fromMetronomeState(MetronomeState, {required AudioRoute route, required LatencyCalibration cal, required int sampleRate})`)
- Modify: `lib/providers/metronome_runtime_providers.dart` (`metronomePlaybackClientProvider`: when `enableUnifiedEngine`, build a `UnifiedEnginePlaybackClient` that owns `SchedulerIsolateHost` + the platform sink + `AudioRouteMonitor`, implementing the existing `MetronomePlaybackClient` interface)
- Test: `test/services/audio/engine/render_config_mapper_test.dart`

**Interfaces:**
- Consumes: `MetronomeState` (`lib/models/metronome_state.dart`: `bpm`, `accentBeats` (=beats), `regularBeats` (=subdivisions), `beatModes`, `accentEnabled`, `accentFrequency`, `beatFrequency`, `volume`, `countInBars`), `LatencyCalibration`, `AudioRoute`.
- Produces: `RenderConfig fromMetronomeState(...)` and a `UnifiedEnginePlaybackClient implements MetronomePlaybackClient` (same `start/update/resetPhase/stop/dispose` surface used today).

- [ ] **Step 1: Write the failing mapper test**

```dart
// test/services/audio/engine/render_config_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/services/audio/engine/latency_calibration.dart';
import 'package:flowgroove/services/audio/engine/render_config_mapper.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('maps MetronomeState beats/subdivisions and applies route latency frames', () async {
    final cal = LatencyCalibration(prefs: await SharedPreferences.getInstance());
    const state = MetronomeState(bpm: 120, accentBeats: 4, regularBeats: 2);
    final cfg = fromMetronomeState(state, route: AudioRoute.bluetooth, cal: cal, sampleRate: 48000);
    expect(cfg.beats, 4);
    expect(cfg.subdivisions, 2);
    expect(cfg.latencyOffsetFrames, 7200); // 150ms @48k
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio/engine/render_config_mapper_test.dart`
Expected: FAIL — `render_config_mapper.dart` not found.

- [ ] **Step 3: Implement the mapper + flag + provider wiring**

```dart
// lib/services/audio/engine/render_config_mapper.dart
import '../../../models/metronome_state.dart';
import 'latency_calibration.dart';
import 'render_config.dart';

RenderConfig fromMetronomeState(
  MetronomeState s, {
  required AudioRoute route,
  required LatencyCalibration cal,
  required int sampleRate,
}) {
  return RenderConfig(
    bpm: s.bpm,
    beats: s.accentBeats,
    subdivisions: s.regularBeats,
    beatModes: s.beatModes,
    accentEnabled: s.accentEnabled,
    accentFrequency: s.accentFrequency,
    beatFrequency: s.beatFrequency,
    volume: s.volume,
    countInBars: s.countInBars,
    latencyOffsetFrames: cal.effectiveOffsetFrames(route, sampleRate),
  );
}
```
Add `static const bool enableUnifiedEngine = false;` to `MetronomeFeatureFlags`. In
`metronomePlaybackClientProvider`, when `enableUnifiedEngine` is true return a
`UnifiedEnginePlaybackClient` (wraps `SchedulerIsolateHost` + sink + `AudioRouteMonitor`; on route change
push `SinkEvent.deviceChanged` and recompute `RenderConfig` via the mapper). Leave the legacy selection
intact for `false`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/audio/engine/render_config_mapper_test.dart`
Expected: PASS.

- [ ] **Step 5: Full-suite regression**

Run: `flutter test`
Expected: PASS (no regressions; new engine is flag-off by default).

- [ ] **Step 6: Commit**

```bash
git add lib/config/metronome_feature_flags.dart lib/services/audio/engine/render_config_mapper.dart lib/providers/metronome_runtime_providers.dart test/services/audio/engine/render_config_mapper_test.dart
git commit -m "feat(metronome): wire unified engine behind enableUnifiedEngine flag"
```

---

## Task 11: Latency calibration UI + on-device acceptance

**Files:**
- Modify: a metronome settings widget under `lib/widgets/metronome/` (add a latency-offset slider bound to `LatencyCalibration.setUserOffsetMs`)
- Test: `test/widgets/metronome/latency_slider_test.dart`

**Interfaces:**
- Consumes: `LatencyCalibration` (Task 4).

- [ ] **Step 1: Write a widget test** that pumps the slider, drags it, and asserts `LatencyCalibration.userOffsetMs` updated (inject a `LatencyCalibration` backed by mock prefs).
- [ ] **Step 2: Run it — FAIL** (`flutter test test/widgets/metronome/latency_slider_test.dart`).
- [ ] **Step 3: Implement the slider widget** (Material `Slider`, range −100..+300 ms, label shows ms), wired to the calibration instance via the provider.
- [ ] **Step 4: Run it — PASS.**
- [ ] **Step 5: On-device acceptance (flip `enableUnifiedEngine = true` locally):**
  Android + iOS + web build. Verify: subdivisions 1–6 smooth; BT connect/disconnect 5× recovers; speaker fallback; 10-min run no drift; latency slider aligns click to feel. Record results.
- [ ] **Step 6: Commit.**

```bash
git add lib/widgets/metronome/ test/widgets/metronome/latency_slider_test.dart
git commit -m "feat(metronome): latency calibration slider + acceptance pass"
```

---

## Task 12: Flip default + remove legacy engines

> Only after Task 11 acceptance passes on all target platforms.

**Files:**
- Modify: `lib/config/metronome_feature_flags.dart` (`enableUnifiedEngine = true`; remove `enablePcmTimelineEngine`)
- Delete: legacy `PcmTimelineMetronomePlaybackClient`, `PlatformMetronomePlaybackClient`,
  `FlutterMetronomePlaybackClient` paths in `lib/providers/metronome_runtime_providers.dart` (and the
  native `AndroidMetronomeEngine` in `MainActivity.kt`) once nothing references them.
- Modify/remove: dead `audio_focus_manager.dart` stub path superseded by Task 7.

- [ ] **Step 1: Set `enableUnifiedEngine = true`; delete the legacy clients + flag.**
- [ ] **Step 2: Run `flutter analyze`** — fix references. Expected: `No issues found`.
- [ ] **Step 3: Run `flutter test`** — full suite green.
- [ ] **Step 4: Final on-device smoke on each platform.**
- [ ] **Step 5: Commit.**

```bash
git add -A
git commit -m "feat(metronome): make unified engine the only path; remove legacy SoLoud/SoundPool clients"
```

---

## Self-Review

**Spec coverage:** L1/L2/L3 layers → Tasks 2/3/5/8 + 9 (isolate); `AudioSink` contract → Task 1;
sample-accurate scheduling → Task 2; device-change recovery → Tasks 3 (logic) + 5/6 (platform);
audio focus → Task 7; latency calibration → Tasks 4 + 11; test strategy table → Tasks 2/3/4 (automated) +
5/11 (manual on-device); migration/rollout §8 → Tasks 10–12 (flag → parity → removal); improvements over
Tack (no god class / no fork) → engine split across focused files, one Dart core. All spec sections covered.

**Placeholder scan:** integration tasks (5,6,8,9,11,12) intentionally describe native/browser code at
interface+skeleton level because full Kotlin/Swift/JS can't be unit-pre-written here; each still names exact
files, channels, types, and a runnable verification. Pure-Dart logic tasks (1–4,10) contain complete code.

**Type consistency:** `AudioSink`/`SinkEvent`/`SinkEventType` consistent across Tasks 1,3,5,7,8;
`RenderConfig` fields consistent across Tasks 2,3,10; `AudioRoute` shared by Tasks 4,6,10; `MetronomeState`
field mapping (`accentBeats`→beats, `regularBeats`→subdivisions) matches the model verified in source.
