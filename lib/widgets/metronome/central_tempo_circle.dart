/// Central tempo circle widget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/mono_pulse_theme.dart';
import '../../models/metronome_tempo_range.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/metronome_selective_providers.dart';
import 'tempo_dial_scale.dart';

/// Central tempo circle with bounded rotary BPM control.
class CentralTempoCircle extends ConsumerStatefulWidget {
  const CentralTempoCircle({super.key});

  @override
  ConsumerState<CentralTempoCircle> createState() => _CentralTempoCircleState();
}

class _CentralTempoCircleState extends ConsumerState<CentralTempoCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomeProvider);
    final notifier = ref.read(metronomeProvider.notifier);

    ref.listen<int>(metronomeCurrentBeatProvider, (previous, next) {
      if (state.isPlaying) _triggerPulse();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : maxWidth;
        final rawDiameter = math.min(maxWidth, maxHeight);
        final diameter = rawDiameter.clamp(120.0, 300.0).toDouble();
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
                    _showBpmInput(context, notifier);
                    return;
                  }
                  _updateTempoFromPosition(details.localPosition, dialSize);
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: CustomPaint(
                        painter: TempoDialPainter(
                          bpm: state.bpm.toDouble(),
                          isPlaying: state.isPlaying,
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
                                  style: MonoPulseTypography.displayLarge
                                      .copyWith(
                                        fontSize: 64,
                                        fontWeight: FontWeight.w700,
                                        color: state.isPlaying
                                            ? MonoPulseColors.accentOrange
                                            : MonoPulseColors.textPrimary,
                                      ),
                                ),
                                Text(
                                  'BPM',
                                  style: MonoPulseTypography.bodyLarge.copyWith(
                                    color: MonoPulseColors.textSecondary
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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

  void _showBpmInput(BuildContext context, MetronomeNotifier notifier) {
    final controller = TextEditingController(
      text: ref.read(metronomeProvider).bpm.toString(),
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set BPM'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            helperText:
                '${MetronomeTempoRange.minimum}-${MetronomeTempoRange.maximum} BPM',
          ),
          onSubmitted: (value) {
            final bpm = int.tryParse(value);
            if (bpm != null) notifier.setBpm(MetronomeTempoRange.clamp(bpm));
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final bpm = int.tryParse(controller.text);
              if (bpm != null) {
                notifier.setBpm(MetronomeTempoRange.clamp(bpm));
              }
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _triggerPulse() {
    final state = ref.read(metronomeProvider);
    final intervalMs = 60000 / state.bpm;
    _pulseController.duration = Duration(
      milliseconds: math.min(200, (intervalMs * 0.8).round()),
    );
    _pulseController.forward(from: 0.0);
  }
}

/// Custom painter for the fixed tempo scale and moving BPM indicator.
class TempoDialPainter extends CustomPainter {
  final double bpm;
  final bool isPlaying;

  TempoDialPainter({required this.bpm, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 20;

    final ringPaint = Paint()
      ..color = MonoPulseColors.textTertiary.withValues(alpha: 0.3)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      TempoDialScale.startAngle,
      TempoDialScale.sweepAngle,
      false,
      ringPaint,
    );

    _drawTickMarks(canvas, center, radius);
    _drawBpmHandle(canvas, center, radius);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = MonoPulseColors.textTertiary.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    final labelPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (final tick in TempoDialScale.majorLabels) {
      final angle = TempoDialScale.bpmToAngle(tick);
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 10);
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(start, end, tickPaint);

      final labelPosition =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 30);
      labelPainter.text = TextSpan(
        text: tick.toString(),
        style: MonoPulseTypography.bodySmall.copyWith(
          color: MonoPulseColors.textTertiary,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        labelPosition - Offset(labelPainter.width / 2, labelPainter.height / 2),
      );
    }
  }

  void _drawBpmHandle(Canvas canvas, Offset center, double radius) {
    final angle = TempoDialScale.bpmToAngle(bpm);
    final handle = center + Offset(math.cos(angle), math.sin(angle)) * radius;

    if (isPlaying) {
      final glowPaint = Paint()
        ..color = MonoPulseColors.accentOrange.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(handle, 12, glowPaint);
    }

    final handlePaint = Paint()
      ..color = isPlaying
          ? MonoPulseColors.accentOrange
          : MonoPulseColors.textTertiary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handle, 8, handlePaint);
  }

  @override
  bool shouldRepaint(TempoDialPainter oldDelegate) {
    return bpm != oldDelegate.bpm || isPlaying != oldDelegate.isPlaying;
  }
}
