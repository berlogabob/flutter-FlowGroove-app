import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/widgets/metronome/tempo_dial_scale.dart';

void main() {
  group('TempoDialScale', () {
    test('maps the minimum, midpoint, and maximum to the fixed arc', () {
      expect(TempoDialScale.bpmToAngle(1), closeTo(2 * math.pi / 3, 0.000001));
      expect(
        TempoDialScale.bpmToAngle(600),
        closeTo(7 * math.pi / 3, 0.000001),
      );

      final midpointAngle = TempoDialScale.bpmToAngle(300.5);
      expect(
        midpointAngle,
        closeTo(
          TempoDialScale.startAngle + TempoDialScale.sweepAngle / 2,
          0.000001,
        ),
      );
    });

    test('round trips representative BPM values within one BPM', () {
      for (final bpm in <int>[1, 37, 120, 240, 360, 480, 599, 600]) {
        final converted = TempoDialScale.angleToBpm(
          TempoDialScale.bpmToAngle(bpm),
        );
        if (converted == null) {
          fail('Expected $bpm to map inside the active dial arc.');
        }
        expect((converted - bpm).abs(), lessThanOrEqualTo(1));
      }
    });

    test('clockwise ring positions increase BPM', () {
      const size = Size.square(300);
      const center = Offset(150, 150);
      const radius = 130.0;
      Offset pointFor(int bpm) {
        final angle = TempoDialScale.bpmToAngle(bpm);
        return center + Offset(math.cos(angle), math.sin(angle)) * radius;
      }

      expect(
        TempoDialScale.positionToBpm(pointFor(480), size)!,
        greaterThan(TempoDialScale.positionToBpm(pointFor(120), size)!),
      );
    });

    test('center, bottom gap, and outside positions are ignored', () {
      const size = Size.square(300);
      expect(
        TempoDialScale.positionToBpm(const Offset(150, 150), size),
        isNull,
      );
      expect(
        TempoDialScale.positionToBpm(const Offset(150, 285), size),
        isNull,
      );
      expect(
        TempoDialScale.positionToBpm(const Offset(150, -50), size),
        isNull,
      );
    });
  });
}
