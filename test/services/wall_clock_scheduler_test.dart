import 'package:flowgroove/services/audio/wall_clock_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WallClockScheduler', () {
    test('fires callback at approximately correct intervals', () async {
      final scheduler = WallClockScheduler();
      final firedTimes = <int>[];
      const interval = Duration(milliseconds: 100);

      scheduler.start(interval, () {
        firedTimes.add(scheduler.elapsedMilliseconds);
      });

      await Future.delayed(const Duration(milliseconds: 550));
      scheduler.stop();

      expect(firedTimes.length, greaterThanOrEqualTo(4));
      expect(firedTimes.length, lessThanOrEqualTo(6));

      for (int i = 1; i < firedTimes.length; i++) {
        final delta = firedTimes[i] - firedTimes[i - 1];
        expect(delta, inInclusiveRange(80, 120));
      }
    });

    test('stop prevents further callbacks', () async {
      final scheduler = WallClockScheduler();
      var callCount = 0;

      scheduler.start(const Duration(milliseconds: 50), () => callCount++);
      await Future.delayed(const Duration(milliseconds: 120));
      scheduler.stop();
      final countAfterStop = callCount;
      await Future.delayed(const Duration(milliseconds: 120));
      expect(callCount, countAfterStop);
    });

    test('updateInterval changes cadence without resetting the phase', () async {
      final scheduler = WallClockScheduler();
      scheduler.start(const Duration(milliseconds: 50), () {});
      await Future.delayed(const Duration(milliseconds: 170)); // ~3 ticks
      final countBefore = scheduler.tickCount;
      expect(countBefore, greaterThanOrEqualTo(2));

      // Swapping the interval must NOT restart counting from 0 (that reset was
      // the metronome "freeze on button-tap" bug).
      scheduler.updateInterval(const Duration(milliseconds: 50));
      expect(scheduler.tickCount, countBefore);

      await Future.delayed(const Duration(milliseconds: 120));
      scheduler.stop();
      expect(scheduler.tickCount, greaterThan(countBefore));
    });

    test('event-loop stall skips missed ticks instead of bursting', () async {
      final scheduler = WallClockScheduler();
      final fires = <({int at, int skipped})>[];
      var stalled = false;

      scheduler.start(const Duration(milliseconds: 100), () {
        fires.add((
          at: scheduler.elapsedMilliseconds,
          skipped: scheduler.lastSkippedTicks,
        ));
        if (!stalled && fires.length == 2) {
          stalled = true;
          // Synchronously block the event loop for ~350ms (3+ intervals).
          final block = Stopwatch()..start();
          while (block.elapsedMilliseconds < 350) {}
        }
      });

      await Future.delayed(const Duration(milliseconds: 900));
      scheduler.stop();

      // Missed ticks were skipped, not replayed: no two callbacks fire
      // back-to-back as a burst.
      for (var i = 1; i < fires.length; i++) {
        expect(
          fires[i].at - fires[i - 1].at,
          greaterThanOrEqualTo(30),
          reason: 'burst detected between fires ${i - 1} and $i: $fires',
        );
      }
      // The stall consumed ~3 intervals; the scheduler reported them skipped.
      expect(scheduler.skippedTickCount, greaterThanOrEqualTo(2));
      // Position (fired + skipped) stays true to wall time within one tick.
      final position = scheduler.tickCount + scheduler.skippedTickCount;
      final wallTicks = fires.last.at ~/ 100;
      expect((position - wallTicks).abs(), lessThanOrEqualTo(1));
    });

    test('tickCount tracks number of ticks', () async {
      final scheduler = WallClockScheduler();
      scheduler.start(const Duration(milliseconds: 50), () {});
      await Future.delayed(const Duration(milliseconds: 270));
      scheduler.stop();
      expect(scheduler.tickCount, greaterThanOrEqualTo(4));
      expect(scheduler.tickCount, lessThanOrEqualTo(6));
    });
  });
}
