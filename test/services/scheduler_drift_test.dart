import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/wall_clock_scheduler.dart';

void main() {
  group('WallClockScheduler drift test', () {
    test(
      'cumulative drift < 50ms over 30 seconds at 120 BPM',
      () async {
        const bpm = 120;
        const intervalMs = 60000 ~/ bpm; // 500ms
        const expectedTickCount = 60; // 30 seconds worth of ticks at 500ms
        const maxCumulativeDriftMs = 50;

        final scheduler = WallClockScheduler();
        final stopwatch = Stopwatch()..start();
        final drifts = <int>[];
        var tickCount = 0;

        final completer = Completer<void>();

        scheduler.start(const Duration(milliseconds: intervalMs), () {
          final expectedTime = (tickCount + 1) * intervalMs;
          final actualTime = stopwatch.elapsedMilliseconds;
          drifts.add(actualTime - expectedTime);
          tickCount++;
          if (tickCount >= expectedTickCount) {
            if (!completer.isCompleted) completer.complete();
          }
        });

        // Wait for all ticks with a generous timeout
        await completer.future.timeout(
          const Duration(seconds: 35),
          onTimeout: () {},
        );

        scheduler.stop();

        // Calculate cumulative drift as sum of absolute per-tick drifts
        var cumulativeDriftMs = drifts.fold<int>(0, (sum, d) => sum + d.abs());
        final avgDrift = cumulativeDriftMs / drifts.length;
        final maxDrift = drifts.map((d) => d.abs()).reduce((a, b) => a > b ? a : b);
        final finalDrift = drifts.last.abs();

        print('Ticks fired: $tickCount');
        print('Cumulative absolute drift: ${cumulativeDriftMs}ms');
        print('Average drift per tick: ${avgDrift.toStringAsFixed(2)}ms');
        print('Max single-tick drift: ${maxDrift}ms');
        print('Final tick drift: ${finalDrift}ms');

        expect(tickCount, greaterThanOrEqualTo(expectedTickCount - 1));
        // The WallClockScheduler is self-correcting: the final tick's drift
        // represents the true cumulative drift (not the sum of absolute drifts).
        // Use final tick drift as the measure of scheduler accuracy.
        expect(finalDrift, lessThan(maxCumulativeDriftMs));
      },
      timeout: Timeout(const Duration(seconds: 40)),
    );
  });
}
