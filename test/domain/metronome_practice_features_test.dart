import 'package:flowgroove/domain/tap_tempo_calculator.dart';
import 'package:flowgroove/models/tempo_ramp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tap tempo averages recent intervals and resets after timeout', () {
    var now = DateTime(2026);
    final calculator = TapTempoCalculator(clock: () => now);

    expect(calculator.tap(), isNull);
    now = now.add(const Duration(milliseconds: 500));
    expect(calculator.tap(), 120);
    now = now.add(const Duration(seconds: 3));
    expect(calculator.tap(), isNull);
  });

  test('bar ramp reaches target without overshooting', () {
    final controller = TempoRampController();
    final start = controller.start(
      const TempoRamp(
        id: 'ramp',
        name: 'Warm up',
        startBpm: 80,
        targetBpm: 85,
        stepBpm: 3,
        cadence: TempoRampCadence.bars,
        every: 2,
      ),
    );

    expect(start, 80);
    expect(controller.onBar(80), isNull);
    expect(controller.onBar(80), 83);
    expect(controller.onBar(83), isNull);
    expect(controller.onBar(83), 85);
    expect(controller.isActive, isFalse);
  });

  test('looping ramp returns to its starting tempo', () {
    final controller = TempoRampController();
    controller.start(
      const TempoRamp(
        id: 'loop',
        name: 'Intervals',
        startBpm: 100,
        targetBpm: 104,
        stepBpm: 4,
        cadence: TempoRampCadence.seconds,
        every: 1,
        loop: true,
      ),
    );

    expect(controller.onSecond(100), 100);
    expect(controller.isActive, isTrue);
  });
}
