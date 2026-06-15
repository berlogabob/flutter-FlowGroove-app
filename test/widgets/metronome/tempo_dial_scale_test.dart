import 'dart:math' as math;

import 'package:flowgroove/widgets/metronome/tempo_dial_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TempoDialScale', () {
    test(
      'maps the display minimum, midpoint, and maximum to the fixed arc',
      () {
        expect(
          TempoDialScale.bpmToAngle(0),
          closeTo(2 * math.pi / 3, 0.000001),
        );
        expect(
          TempoDialScale.bpmToAngle(400),
          closeTo(7 * math.pi / 3, 0.000001),
        );

        final midpointAngle = TempoDialScale.bpmToAngle(200);
        expect(
          midpointAngle,
          closeTo(
            TempoDialScale.startAngle + TempoDialScale.sweepAngle / 2,
            0.000001,
          ),
        );
        expect(TempoDialScale.angleToBpm(TempoDialScale.startAngle), 1);
      },
    );

    test('round trips representative BPM values within one BPM', () {
      for (final bpm in <int>[1, 37, 80, 160, 240, 320, 399, 400]) {
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
        TempoDialScale.positionToBpm(pointFor(320), size),
        greaterThan(TempoDialScale.positionToBpm(pointFor(80), size)!),
      );
    });

    test('uses evenly spaced round-number labels', () {
      expect(
        TempoDialScale.majorLabels,
        equals(<int>[0, 80, 160, 240, 320, 400]),
      );

      final angles = TempoDialScale.majorLabels
          .map(TempoDialScale.bpmToAngle)
          .toList();
      final intervals = <double>[
        for (var index = 1; index < angles.length; index++)
          angles[index] - angles[index - 1],
      ];
      for (final interval in intervals.skip(1)) {
        expect(interval, closeTo(intervals.first, 0.000001));
      }
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
