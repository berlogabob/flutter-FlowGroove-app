import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/metronome_tempo_range.dart';

/// Geometry for the bounded metronome tempo dial.
///
/// Flutter canvas angles start at the positive x-axis and increase clockwise.
/// The active scale runs from 120 degrees through a 300-degree sweep, leaving
/// a 60-degree dead zone centered at the bottom of the dial.
class TempoDialScale {
  const TempoDialScale._();

  static const double startAngle = 2 * math.pi / 3;
  static const double sweepAngle = 5 * math.pi / 3;
  static const List<int> majorLabels = <int>[1, 120, 240, 360, 480, 600];

  static double bpmToAngle(num bpm) {
    final clampedBpm = bpm
        .clamp(MetronomeTempoRange.minimum, MetronomeTempoRange.maximum)
        .toDouble();
    final progress =
        (clampedBpm - MetronomeTempoRange.minimum) /
        (MetronomeTempoRange.maximum - MetronomeTempoRange.minimum);
    return startAngle + progress * sweepAngle;
  }

  static int? angleToBpm(double angle) {
    final relativeAngle = _normalizeAngle(angle - startAngle);
    if (relativeAngle > sweepAngle + 0.000001) return null;

    final progress = (relativeAngle / sweepAngle).clamp(0.0, 1.0);
    final bpm =
        MetronomeTempoRange.minimum +
        progress * (MetronomeTempoRange.maximum - MetronomeTempoRange.minimum);
    return MetronomeTempoRange.clamp(bpm);
  }

  static int? positionToBpm(
    Offset localPosition,
    Size size, {
    double innerRadiusFactor = 0.42,
    double outerRadiusFactor = 1.15,
  }) {
    if (size.isEmpty) return null;

    final center = size.center(Offset.zero);
    final delta = localPosition - center;
    final radius = math.min(size.width, size.height) / 2;
    final distance = delta.distance;

    if (distance < radius * innerRadiusFactor ||
        distance > radius * outerRadiusFactor) {
      return null;
    }

    return angleToBpm(math.atan2(delta.dy, delta.dx));
  }

  static bool isCenterPosition(
    Offset localPosition,
    Size size, {
    double innerRadiusFactor = 0.42,
  }) {
    if (size.isEmpty) return false;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    return (localPosition - center).distance < radius * innerRadiusFactor;
  }

  static double _normalizeAngle(double angle) {
    final normalized = angle % (2 * math.pi);
    return normalized < 0 ? normalized + 2 * math.pi : normalized;
  }
}
