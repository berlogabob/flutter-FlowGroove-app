import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/wall_clock_scheduler.dart';

void main() {
  group('WallClockScheduler', () {
    test('fires callback at approximately correct intervals', () async {
      final scheduler = WallClockScheduler();
      final firedTimes = <int>[];
      final interval = Duration(milliseconds: 100);

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
