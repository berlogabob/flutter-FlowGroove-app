import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_sink.dart';
import 'pcm_click_renderer.dart';
import 'render_config.dart';

class MetronomeScheduler {
  MetronomeScheduler({
    required AudioSink sink,
    required PcmClickRenderer renderer,
    this.chunk = const Duration(milliseconds: 200),
    int sampleRate = 48000,
    bool testMode = false,
    int Function()? clockMicros,
  })  : _sink = sink,
        _renderer = renderer,
        _sampleRate = sampleRate,
        _testMode = testMode,
        _clockMicros = clockMicros {
    _sub = _sink.events.listen(_onSinkEvent);
  }

  final AudioSink _sink;
  final PcmClickRenderer _renderer;
  final Duration chunk;
  final int _sampleRate;
  final bool _testMode;

  /// Injectable monotonic clock (microseconds). Tests drive it directly; in
  /// production it is [_stopwatch]. The feeder is anchored to the SAME Dart
  /// monotonic clock the UI's WallClockScheduler uses, so audio and the beat
  /// animation agree by construction (closing the loop on the device clock
  /// would let them free-run apart).
  final int Function()? _clockMicros;
  final Stopwatch _stopwatch = Stopwatch();

  late final StreamSubscription<SinkEvent> _sub;
  RenderConfig? _config;
  int _frame = 0;
  bool _running = false;
  bool _recovering = false;
  Timer? _pump;

  /// Look-ahead depth kept ahead of the play head (3 * chunk = ~600ms at the
  /// 200ms default). Also the start prime. Deeper would absorb longer stalls
  /// but makes tempo changes land later, and stalls past it now degrade
  /// gracefully (resync) instead of failing permanently — so 3 stands.
  static const int _lookaheadChunks = 3;

  /// Invariant guard: the resync rule already bounds real work to ~4 chunks,
  /// so tripping this means the arithmetic is wrong. Never render more than
  /// 1.2s in one callback.
  static const int _maxChunksPerPump = 6;

  /// A recover() is a process-wide SoLoud deinit()+init(). Retry a transient
  /// failure a few times, then stop; the budget is restored by a `recovered`
  /// event (i.e. proof that a recovery actually worked).
  static const int _maxRecoverAttempts = 3;
  static const Duration _recoverBackoffBase = Duration(milliseconds: 250);

  /// Cap on resync log lines per session (counters keep counting past it).
  static const int _maxStarvationLogs = 20;

  int _recoverAttempts = 0;

  // Diagnostics (see debugStats). Never gate rendering on these.
  int _pumpCount = 0;
  int _pushedChunks = 0;
  int _starvationEvents = 0;
  int _droppedFrames = 0;
  int _cappedPumps = 0;
  int _recoverCount = 0;
  int _recoverGiveUps = 0;
  int _lastQueuedFrames = 0;

  int get currentFrame => _frame;
  int get _chunkFrames => (_sampleRate * chunk.inMilliseconds / 1000).round();
  int get _lookaheadFrames => _lookaheadChunks * _chunkFrames;

  int _nowMicros() => _clockMicros?.call() ?? _stopwatch.elapsedMicroseconds;

  int get starvationEvents => _starvationEvents;
  int get droppedFrames => _droppedFrames;
  int get cappedPumps => _cappedPumps;
  int get recoverGiveUps => _recoverGiveUps;

  /// Snapshot for on-device diagnosis of feeder starvation (#151).
  Map<String, Object> debugStats() => {
        'pumpCount': _pumpCount,
        'pushedChunks': _pushedChunks,
        'starvationEvents': _starvationEvents,
        'droppedFrames': _droppedFrames,
        'droppedMs': _droppedFrames * 1000 ~/ _sampleRate,
        'queuedFrames': _lastQueuedFrames,
        'queuedMs': _lastQueuedFrames * 1000 ~/ _sampleRate,
        'cappedPumps': _cappedPumps,
        'recoverCount': _recoverCount,
        'recoverGiveUps': _recoverGiveUps,
      };

  void _resetStats() {
    _pumpCount = 0;
    _pushedChunks = 0;
    _starvationEvents = 0;
    _droppedFrames = 0;
    _cappedPumps = 0;
    _recoverCount = 0;
    _recoverGiveUps = 0;
    _lastQueuedFrames = 0;
    _recoverAttempts = 0;
  }

  Future<void> start(RenderConfig config) async {
    _config = config;
    _frame = 0;
    _running = true;
    _resetStats();
    await _sink.open(sampleRate: _sampleRate, channels: 1);
    // Clock starts AFTER open(): SoLoud init can take 100ms+, and counting it
    // as elapsed playback would drop that much audio on the very first pump.
    _stopwatch
      ..reset()
      ..start();
    // The prime is just "hit the target at t≈0" — one code path, so the
    // catch-up arithmetic is exercised from the first pump.
    _pumpToTarget();
    if (!_testMode) {
      _pump = Timer.periodic(chunk, (_) => _pumpToTarget());
    }
  }

  void update(RenderConfig config) => _config = config;

  /// Render forward until the buffer holds [_lookaheadFrames] beyond *now*.
  ///
  /// The old feeder pushed exactly one chunk per timer callback, and Dart
  /// never replays a missed callback — so every stalled callback was 200ms of
  /// audio that was never produced, permanently (#151). Anchoring the write
  /// cursor to elapsed wall time instead makes production independent of
  /// callback count.
  void _pumpToTarget() {
    if (!_running || _recovering) return;
    final c = _config;
    if (c == null) return;
    _pumpCount++;

    final elapsedFrames = (_nowMicros() * _sampleRate) ~/ 1000000;

    // Diagnostics only, and a sink must never be able to break playback.
    try {
      _lastQueuedFrames = _sink.framesQueued;
    } on Object {
      _lastQueuedFrames = 0;
    }

    // Resync: frames behind the play head are already in the past — the device
    // emitted silence for exactly that span while we were stalled. Rendering
    // them would keep the grid permanently late. Assign elapsedFrames verbatim:
    // tick positions come from the ABSOLUTE frame index, so phase is preserved
    // by construction. Snapping to a chunk/tick boundary would shift it.
    if (_frame < elapsedFrames) {
      _droppedFrames += elapsedFrames - _frame;
      _starvationEvents++;
      // Logged in release too: #151 was only measurable on a release build,
      // and post-fix a resync means the app was starved past the whole
      // lookahead — rare enough not to be chatty. Capped so a pathological
      // device can't fill the log (the counter keeps counting either way).
      if (_starvationEvents <= _maxStarvationLogs) {
        final ms = (elapsedFrames - _frame) * 1000 ~/ _sampleRate;
        debugPrint('[MetronomeScheduler] resync: dropped ${ms}ms of audio '
            '(event $_starvationEvents)');
      }
      _frame = elapsedFrames;
    }

    final target = elapsedFrames + _lookaheadFrames;
    var chunks = 0;
    while (_frame < target) {
      if (chunks >= _maxChunksPerPump) {
        _cappedPumps++;
        break;
      }
      final frames = _renderer.renderChunk(
          config: c, startFrame: _frame, frameCount: _chunkFrames);
      _sink.pushFrames(frames);
      _frame += _chunkFrames;
      chunks++;
      _pushedChunks++;
    }
  }

  /// Test seam: deterministic pump (no real timer).
  void pumpForTest() => _pumpToTarget();

  Future<void> _tryRecover() async {
    // Re-entrancy guard: pushFrames emits `error` on every failed push (5/s at
    // the default chunk), so without this a broken sink stampedes recovery.
    if (_recovering || !_running) return;
    if (_recoverAttempts >= _maxRecoverAttempts) {
      _recoverGiveUps++;
      return;
    }
    _recoverAttempts++;
    _recoverCount++;
    _recovering = true;
    try {
      if (_recoverAttempts > 1) {
        await Future<void>.delayed(_recoverBackoffBase * (_recoverAttempts - 1));
      }
      await _sink.recover(atFrame: _frame);
    } finally {
      _recovering = false;
    }
    _pumpToTarget();
  }

  Future<void> _onSinkEvent(SinkEvent e) async {
    switch (e.type) {
      case SinkEventType.deviceChanged:
      case SinkEventType.error:
        // Both consume the budget. Deliberately NOT reset here: a sink that
        // echoes deviceChanged out of recover() would otherwise restart
        // recovery forever, and whether the echo lands before or after the
        // `_recovering` flag clears is pure event-loop ordering luck.
        await _tryRecover();
      case SinkEventType.recovered:
        // Proof the sink is healthy again — the only thing that restores the
        // budget mid-session, so repeated genuine route changes keep working.
        // recover() takes ~100-300ms; top the buffer up now rather than
        // waiting for the next timer tick.
        _recoverAttempts = 0;
        _pumpToTarget();
      case SinkEventType.underrun:
        _pumpToTarget();
      case SinkEventType.focusLost:
      case SinkEventType.focusGained:
        break;
    }
  }

  Future<void> stop() async {
    // Session summary, release included — the numbers behind #151 without
    // needing any debug UI (read with `flutter logs -d <device>`).
    if (_pumpCount > 0) {
      debugPrint('[MetronomeScheduler] session ${debugStats()}');
    }
    _running = false;
    _stopwatch.stop();
    _pump?.cancel();
    await _sub.cancel();
    await _sink.close();
  }
}
