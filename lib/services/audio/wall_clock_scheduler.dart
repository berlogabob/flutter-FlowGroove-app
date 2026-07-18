import 'dart:async';

class WallClockScheduler {
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _interval = Duration.zero;
  void Function()? _callback;
  int _tickCount = 0;
  int _nextTargetMs = 0;
  int _pendingSkipped = 0;
  int _lastSkippedTicks = 0;
  int _skippedTickCount = 0;

  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;
  int get tickCount => _tickCount;

  /// Ticks that were silently skipped (not fired) immediately before the
  /// current callback, because the event loop stalled past their targets.
  /// Consumers advance their beat position by `1 + lastSkippedTicks`.
  int get lastSkippedTicks => _lastSkippedTicks;

  /// Total skipped ticks since [start].
  int get skippedTickCount => _skippedTickCount;

  void start(Duration interval, void Function() callback) {
    stop();
    _interval = interval;
    _callback = callback;
    _tickCount = 0;
    _nextTargetMs = 0;
    _pendingSkipped = 0;
    _lastSkippedTicks = 0;
    _skippedTickCount = 0;
    _stopwatch.reset();
    _stopwatch.start();
    _scheduleNext();
  }

  /// Swap the tick interval without resetting the running phase. The already
  /// scheduled timer fires on time; subsequent ticks use the new interval.
  void updateInterval(Duration interval) => _interval = interval;

  void _scheduleNext() {
    if (_callback == null) return;
    _nextTargetMs += _interval.inMilliseconds;
    final now = _stopwatch.elapsedMilliseconds;
    var delayMs = _nextTargetMs - now;
    // After an event-loop stall, jump past fully missed targets instead of
    // replaying them as a zero-delay burst (the audible "machine gun" bug).
    // The consumer reads [lastSkippedTicks] to keep its beat position true
    // to wall time.
    final intervalMs = _interval.inMilliseconds;
    var skipped = 0;
    if (delayMs < 0 && intervalMs > 0) {
      skipped = (-delayMs) ~/ intervalMs;
      if (skipped > 0) {
        _nextTargetMs += skipped * intervalMs;
        delayMs = _nextTargetMs - now;
      }
    }
    _pendingSkipped = skipped;
    final delay = delayMs > 0 ? Duration(milliseconds: delayMs) : Duration.zero;
    _timer = Timer(delay, _onTick);
  }

  void _onTick() {
    if (_callback == null) return;
    _tickCount++;
    _lastSkippedTicks = _pendingSkipped;
    _skippedTickCount += _pendingSkipped;
    _pendingSkipped = 0;
    _callback!();
    _scheduleNext();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _callback = null;
  }

  void dispose() {
    stop();
  }
}
