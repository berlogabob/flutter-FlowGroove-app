import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';

/// Static Tick Marks widget for Tuner dial
///
/// Displays tick marks around the central circle:
/// - 12 major tick marks (every 30 degrees)
/// - Labels for key frequencies (e.g., "440", "A4")
/// - Thin lines in #333333, labels in #8A8A8F
/// - Length: 8-12px for tick marks
///
/// This is a STATIC widget (Stage 1 - no interactivity).
class TickMarks extends StatelessWidget {
  final double size;

  const TickMarks({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TickMarksPainter(size: size)),
    );
  }
}

class _TickMarksPainter extends CustomPainter {
  final double size;

  _TickMarksPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = canvasSize.width / 2;

    // Tick mark paint - thin lines
    final tickPaint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Label paint
    final labelPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Static tick marks data (12 positions around the circle)
    // Each position has: angle (degrees), label (empty string = no label), subLabel
    const tickData = [
      {'angle': -90.0, 'label': 'A4', 'subLabel': '440'}, // Top (12 o'clock)
      {'angle': -60.0, 'label': '', 'subLabel': ''},
      {'angle': -30.0, 'label': '', 'subLabel': ''},
      {'angle': 0.0, 'label': '', 'subLabel': ''}, // 3 o'clock
      {'angle': 30.0, 'label': '', 'subLabel': ''},
      {'angle': 60.0, 'label': '', 'subLabel': ''},
      {'angle': 90.0, 'label': 'E4', 'subLabel': '330'}, // Bottom (6 o'clock)
      {'angle': 120.0, 'label': '', 'subLabel': ''},
      {'angle': 150.0, 'label': '', 'subLabel': ''},
      {'angle': 180.0, 'label': '', 'subLabel': ''}, // 9 o'clock
      {'angle': 210.0, 'label': '', 'subLabel': ''},
      {'angle': 240.0, 'label': 'D4', 'subLabel': '294'},
    ];

    for (final tick in tickData) {
      final angleDeg = tick['angle'] as double;
      final label = tick['label'] as String;
      final subLabel = tick['subLabel'] as String;
      final angleRad = angleDeg * (math.pi / 180);

      // Determine if this is a major tick (has non-empty label)
      final isMajor = label.isNotEmpty;

      // Tick mark dimensions
      final tickLength = isMajor ? size * 0.035 : size * 0.025;
      final tickStartRadius = radius - tickLength;

      // Calculate tick endpoints
      final x1 = center.dx + tickStartRadius * math.cos(angleRad);
      final y1 = center.dy + tickStartRadius * math.sin(angleRad);
      final x2 = center.dx + radius * math.cos(angleRad);
      final y2 = center.dy + radius * math.sin(angleRad);

      // Draw tick mark
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        tickPaint
          ..color = isMajor
              ? MonoPulseColors.borderDefault
              : MonoPulseColors.borderSubtle,
      );

      // Draw labels for major ticks
      if (isMajor) {
        final labelRadius = radius - size * 0.1;
        final labelX = center.dx + labelRadius * math.cos(angleRad);
        final labelY = center.dy + labelRadius * math.sin(angleRad);

        // Draw main label (e.g., "A4") - 14px Regular per brandbook
        labelPaint.text = TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 14,
            color: MonoPulseColors.textTertiary,
            fontWeight: MonoPulseTypography.regular,
          ),
        );
        labelPaint.layout();
        labelPaint.paint(
          canvas,
          Offset(labelX - labelPaint.width / 2, labelY - labelPaint.height / 2),
        );

        // Draw sub-label (e.g., "440") below main label if present - 14px Regular
        if (subLabel.isNotEmpty) {
          final subLabelRadius = radius - size * 0.14;
          final subLabelX = center.dx + subLabelRadius * math.cos(angleRad);
          final subLabelY = center.dy + subLabelRadius * math.sin(angleRad);

          labelPaint.text = TextSpan(
            text: subLabel,
            style: const TextStyle(
              fontSize: 14,
              color: MonoPulseColors.textTertiary,
              fontWeight: MonoPulseTypography.regular,
            ),
          );
          labelPaint.layout();
          labelPaint.paint(
            canvas,
            Offset(
              subLabelX - labelPaint.width / 2,
              subLabelY - labelPaint.height / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
