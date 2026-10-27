import 'package:flutter/material.dart';

import '../../theme/mono_pulse_theme.dart';

/// Bars, dimmed outside the trim window, with marker ticks and a playhead.
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.peaks,
    required this.trimStart,
    required this.trimEnd,
    required this.playhead,
    required this.markerFractions,
    required this.dim,
  });

  final List<int> peaks;
  final double trimStart;
  final double trimEnd;
  final double playhead;
  final List<double> markerFractions;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
    final step = size.width / peaks.length;
    final mid = size.height / 2;
    final bar = Paint()
      ..strokeWidth = (step * 0.6).clamp(1.0, 6.0)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < peaks.length; i++) {
      final fraction = (i + 0.5) / peaks.length;
      final inside = fraction >= trimStart && fraction <= trimEnd;
      bar.color = inside
          ? MonoPulseColors.accentOrange
          : dim.withValues(alpha: 0.3);
      // Keep silence visible as a hairline rather than nothing at all.
      final h = (peaks[i] / 255).clamp(0.03, 1.0) * mid;
      final x = i * step + step / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), bar);
    }

    final tick = Paint()..color = dim;
    for (final f in markerFractions) {
      final x = f * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, 6), tick);
    }

    canvas.drawLine(
      Offset(playhead * size.width, 0),
      Offset(playhead * size.width, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.playhead != playhead ||
      old.trimStart != trimStart ||
      old.trimEnd != trimEnd ||
      old.peaks != peaks ||
      old.markerFractions.length != markerFractions.length;
}
