import 'dart:async';
import 'dart:math' as math;

import '../../utils/bar_math.dart';
import 'backing_engine.dart';

export 'backing_engine_stub.dart'
    if (dart.library.js_interop) 'backing_engine_web.dart';

/// Uses the click client's AudioContext clock and barTimeSeconds directly.
abstract class BackingClock {
  double? get currentTime;
  double get bpm;
  double barTimeSeconds(int bar);
}

abstract class BackingSource {
  void stop(double atTime);
}

abstract class BackingSourceFactory {
  int get sampleRate;
  void load(BackingStems stems);
  BackingSource start(int stem, double atTime, double offset, double duration);
  void setGain(int stem, double gain);
  void clear();
}

/// VM-testable scheduling; browser nodes and the audio clock are injected.
class WebBackingScheduler implements BackingEngine {
  WebBackingScheduler({
    required this.clock,
    required this.sources,
    this.automaticPump = true,
  });

  final BackingClock clock;
  final BackingSourceFactory sources;
  final bool automaticPump;
  final _states = StreamController<BackingState>.broadcast();
  final _bars = StreamController<int>.broadcast();
  final _pending = <BackingCommand>[];
  final _scheduled = <({int bar, double end, BackingSource source})>[];
  BackingStems? _stems;
  BackingCommand? _playing;
  Timer? _timer;
  int? _nextBar;
  int? _lastBar;

  @override
  Stream<BackingState> get states => _states.stream;

  @override
  Stream<int> get bars => _bars.stream;

  @override
  Future<int> engineSampleRate() async => sources.sampleRate;

  @override
  Future<void> load(BackingStems stems) async {
    if (stems.sampleRate <= 0 ||
        !stems.renderBpm.isFinite ||
        stems.renderBpm <= 0 ||
        stems.ticksPerBar <= 0 ||
        stems.intervalMicros <= 0 ||
        stems.ticksPerBar * stems.intervalMicros * stems.sampleRate / 1e6 < 1) {
      throw ArgumentError('Invalid backing tempo or grid');
    }
    await clear();
    sources.load(stems);
    _stems = stems;
    if (automaticPump) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => pump());
    }
  }

  @override
  Future<void> command(BackingCommand c) async {
    if (c.atBar < 0 ||
        (c.kind == BackingKind.launch && (c.fromBar < 0 || c.bars <= 0))) {
      throw ArgumentError('Invalid backing bar range');
    }
    final index = _pending.indexWhere((other) => other.atBar > c.atBar);
    _pending.insert(index < 0 ? _pending.length : index, c);
    _states.add(BackingState(c.token, BackingStateKind.queued, c.atBar));
    _cancelFrom(c.atBar);
    _nextBar = math.min(_nextBar ?? c.atBar, c.atBar);
    pump();
  }

  void _cancelFrom(int bar) {
    final now = clock.currentTime ?? 0;
    for (final entry in _scheduled.where((entry) => entry.bar >= bar)) {
      entry.source.stop(now);
    }
    _scheduled.removeWhere((entry) => entry.bar >= bar);
  }

  void _finish(int bar) {
    final playing = _playing;
    if (playing != null &&
        !playing.loop &&
        bar >= playing.atBar + playing.bars) {
      _states.add(
        BackingState(
          playing.token,
          BackingStateKind.stopped,
          playing.atBar + playing.bars,
        ),
      );
      _playing = null;
    }
  }

  /// Fill at least two bars (or three seconds), without scheduling the song ahead.
  void pump() {
    final stems = _stems;
    final now = clock.currentTime;
    final barSeconds = clock.barTimeSeconds(1) - clock.barTimeSeconds(0);
    if (stems == null || now == null || barSeconds <= 0) return;
    var currentBar = ((now - clock.barTimeSeconds(0)) / barSeconds).floor();
    // Division can land either side of an exact floating-point bar boundary.
    while (clock.barTimeSeconds(currentBar) > now) {
      currentBar--;
    }
    while (clock.barTimeSeconds(currentBar + 1) <= now) {
      currentBar++;
    }
    if (currentBar >= 0 && currentBar != _lastBar) {
      _bars.add(currentBar);
      _lastBar = currentBar;
    }
    while (_pending.isNotEmpty &&
        clock.barTimeSeconds(_pending.first.atBar) <= now) {
      final c = _pending.removeAt(0);
      _finish(c.atBar);
      _playing = c.kind == BackingKind.launch ? c : null;
      _states.add(
        BackingState(
          c.token,
          c.kind == BackingKind.launch
              ? BackingStateKind.playing
              : BackingStateKind.stopped,
          c.atBar,
        ),
      );
    }
    _finish(currentBar);
    _scheduled.removeWhere((entry) => entry.end <= now);
    if ((stems.renderBpm - clock.bpm).abs() >= 0.001 || !clock.bpm.isFinite) {
      _cancelFrom(0);
      _nextBar = null;
      return;
    }
    // Skip missed bars after timer throttling; offsets still follow transport.
    final firstBar = math.max(
      0,
      clock.barTimeSeconds(currentBar) == now ? currentBar : currentBar + 1,
    );
    var bar = math.max(_nextBar ?? firstBar, firstBar);
    final horizon = now + math.max(3, 2 * barSeconds);
    while (clock.barTimeSeconds(bar) < horizon) {
      var command = _playing;
      for (final pending in _pending) {
        if (pending.atBar > bar) break;
        command = pending;
      }
      if (command != null && command.kind == BackingKind.launch) {
        final elapsed = bar - command.atBar;
        if (elapsed >= 0 && (command.loop || elapsed < command.bars)) {
          final songBar =
              command.fromBar +
              (command.loop ? elapsed % command.bars : elapsed);
          final offset =
              barStartFrame(
                bar: songBar,
                ticksPerBar: stems.ticksPerBar,
                intervalMicros: stems.intervalMicros.toDouble(),
                sampleRate: stems.sampleRate,
                epochFrame: 0,
              ) /
              stems.sampleRate;
          final start = clock.barTimeSeconds(bar);
          final end = clock.barTimeSeconds(bar + 1);
          for (var stem = 0; stem < stems.stems.length; stem++) {
            _scheduled.add((
              bar: bar,
              end: end,
              source: sources.start(stem, start, offset, end - start),
            ));
          }
        }
      }
      bar++;
    }
    _nextBar = bar;
  }

  @override
  void setGain(int stem, double gain) {
    if (_stems == null || stem < 0 || stem >= _stems!.stems.length) {
      throw ArgumentError.value(stem, 'stem');
    }
    if (!gain.isFinite) throw ArgumentError.value(gain, 'gain');
    sources.setGain(stem, gain);
  }

  @override
  Future<void> clear() async {
    _timer?.cancel();
    _timer = null;
    _cancelFrom(0);
    _pending.clear();
    _playing = null;
    _stems = null;
    _nextBar = null;
    _lastBar = null;
    sources.clear();
  }

  @override
  Future<void> dispose() async {
    await clear();
    await _states.close();
    await _bars.close();
  }
}
