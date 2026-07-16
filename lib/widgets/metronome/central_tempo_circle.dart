/// Central tempo circle widget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/mono_pulse_theme.dart';
import '../../models/metronome_tempo_range.dart';
import '../../providers/data/metronome_provider.dart';
import 'bpm_input_overlay.dart';
import 'tempo_dial_scale.dart';

/// Central tempo circle with bounded rotary BPM control.
class CentralTempoCircle extends ConsumerStatefulWidget {
  const CentralTempoCircle({super.key});

  @override
  ConsumerState<CentralTempoCircle> createState() => _CentralTempoCircleState();
}

class _CentralTempoCircleState extends ConsumerState<CentralTempoCircle> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : maxWidth;
        final rawDiameter = math.min(maxWidth, maxHeight);
        final diameter = rawDiameter.clamp(120.0, 300.0);
        final dialSize = Size.square(diameter);

        return Center(
          child: Semantics(
            label: 'Tempo dial',
            value: '${state.bpm} BPM',
            increasedValue: '${MetronomeTempoRange.clamp(state.bpm + 1)} BPM',
            decreasedValue: '${MetronomeTempoRange.clamp(state.bpm - 1)} BPM',
            onIncrease: () => notifier.setBpm(state.bpm + 1),
            onDecrease: () => notifier.setBpm(state.bpm - 1),
            child: SizedBox.fromSize(
              size: dialSize,
              child: GestureDetector(
                key: const Key('tempo-dial'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) =>
                    _updateTempoFromPosition(details.localPosition, dialSize),
                onPanUpdate: (details) =>
                    _updateTempoFromPosition(details.localPosition, dialSize),
                onTapUp: (details) {
                  if (TempoDialScale.isCenterPosition(
                    details.localPosition,
                    dialSize,
                  )) {
                    showTempoInputSheet(context);
                    return;
                  }
                  _updateTempoFromPosition(details.localPosition, dialSize);
                },
                child: CustomPaint(
                  painter: TempoDialPainter(
                    bpm: state.bpm.toDouble(),
                    isPlaying: state.isPlaying,
                    trackColor: context.mp.surfaceOverlay,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.bpm.toString(),
                            style: MonoPulseTypography.displayLarge.copyWith(
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                              color: state.isPlaying
                                  ? MonoPulseColors.accentOrange
                                  : context.mp.textPrimary,
                            ),
                          ),
                          Text(
                            'BPM',
                            style: MonoPulseTypography.bodyLarge.copyWith(
                              color: context.mp.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateTempoFromPosition(Offset localPosition, Size dialSize) {
    final newBpm = TempoDialScale.positionToBpm(localPosition, dialSize);
    if (newBpm == null) return;

    final oldBpm = ref.read(metronomeProvider).bpm;
    if (newBpm == oldBpm) return;

    ref.read(metronomeProvider.notifier).setBpm(newBpm);
    if (oldBpm ~/ 5 != newBpm ~/ 5) {
      HapticFeedback.selectionClick();
    }
  }
}

/// Simplified Mono Pulse tempo dial: a thick grey track with an orange
/// progress arc filling from the start of the gauge to the current BPM, and a
/// white knob (orange ring) at the arc head. No tick labels — the centred BPM
/// readout carries the number (audit A6: "simplified dial").
class TempoDialPainter extends CustomPainter {
  TempoDialPainter({
    required this.bpm,
    required this.isPlaying,
    required this.trackColor,
  });
  final double bpm;
  final bool isPlaying;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final stroke = (radius * 0.16).clamp(10.0, 18.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Grey track (full gauge sweep).
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      rect,
      TempoDialScale.startAngle,
      TempoDialScale.sweepAngle,
      false,
      trackPaint,
    );

    // Orange progress arc from the gauge start to the current BPM.
    final currentAngle = TempoDialScale.bpmToAngle(bpm);
    final progressSweep = currentAngle - TempoDialScale.startAngle;
    final progressPaint = Paint()
      ..color = MonoPulseColors.accentOrange
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (progressSweep > 0) {
      canvas.drawArc(
        rect,
        TempoDialScale.startAngle,
        progressSweep,
        false,
        progressPaint,
      );
    }

    // White knob with an orange ring at the arc head.
    final knob =
        center +
        Offset(math.cos(currentAngle), math.sin(currentAngle)) * radius;
    canvas.drawCircle(
      knob,
      stroke * 0.62,
      Paint()
        ..color = MonoPulseColors.accentOrange
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      knob,
      stroke * 0.42,
      Paint()
        ..color = MonoPulseColors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(TempoDialPainter oldDelegate) {
    return bpm != oldDelegate.bpm ||
        isPlaying != oldDelegate.isPlaying ||
        trackColor != oldDelegate.trackColor;
  }
}
