import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import 'tempo_change_dialog.dart';

/// Central Tempo Circle widget - Mono Pulse design
///
/// Large rotary dial for tempo adjustment:
/// - Circle diameter ~50-60% screen width
/// - Background: #121212, stroke: 1px #222222
/// - Small dot/handle: #FF5E00 on edge
/// - Tick marks with labels (60, 120, 180 bpm)
/// - Center: BPM number (72-88px Bold) + "bpm" label
///
/// Behavior:
/// - Drag finger to rotate and set tempo (rotary phone style)
/// - Tap center: modal dialog with Tap/Keyboard options
class CentralTempoCircle extends ConsumerStatefulWidget {
  const CentralTempoCircle({super.key});

  @override
  ConsumerState<CentralTempoCircle> createState() => _CentralTempoCircleState();
}

class _CentralTempoCircleState extends ConsumerState<CentralTempoCircle>
    with TickerProviderStateMixin {
  double _startAngle = 0;
  double _currentRotation = 0;
  int _startBpm = 120;
  bool _isDragging = false;

  // Pulse animation controller for beat feedback
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: MonoPulseAnimation.durationShort,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: MonoPulseAnimation.curveCustom,
      ),
    );

    // Listen to metronome state changes for beat pulse
    ref.listen(metronomeProvider, (previous, next) {
      if (next.isPlaying && next.currentBeat != (previous?.currentBeat ?? -1)) {
        _triggerPulse();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);
    final bpm = state.bpm;

    // Calculate rotation angle based on BPM (1-600 range = 0-360 degrees)
    final normalizedBpm = (bpm - 1) / 599; // 0-1 range
    final targetRotation = normalizedBpm * 360;

    // Use LayoutBuilder to make circle 55% of screen width
    return LayoutBuilder(
      builder: (context, constraints) {
        final circleSize = constraints.maxWidth * 0.55;
        final clampedSize = circleSize.clamp(220.0, 280.0);

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Center(
            child: SizedBox(
              width: clampedSize,
              height: clampedSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer tick marks and labels
                  _TickMarks(size: clampedSize),

                  // Main rotary dial
                  AnimatedRotation(
                    turns: _isDragging
                        ? _currentRotation / 360
                        : targetRotation / 360,
                    duration: _isDragging
                        ? Duration.zero
                        : MonoPulseAnimation.durationMedium,
                    curve: MonoPulseAnimation.curveCustom,
                    child: _RotaryDial(
                      size: clampedSize * 0.85,
                      bpm: bpm,
                      onTap: () => _showTempoDialog(context, metronome),
                    ),
                  ),

                  // Center BPM display with pulse animation (not rotating)
                  AnimatedScale(
                    scale: _pulseController.isAnimating
                        ? _pulseAnimation.value
                        : 1.0,
                    duration: MonoPulseAnimation.durationShort,
                    curve: MonoPulseAnimation.curveCustom,
                    child: _BpmDisplay(bpm: bpm, size: clampedSize),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _startBpm = ref.read(metronomeProvider).bpm;
      _startAngle = _getAngle(details.localPosition);
      _currentRotation = (_startBpm - 1) / 599 * 360;
    });
    HapticFeedback.vibrate();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final angle = _getAngle(details.localPosition);
    final angleDiff = angle - _startAngle;

    setState(() {
      _currentRotation = ((_startBpm - 1) / 599 * 360) + angleDiff;
    });

    // Update BPM in real-time
    final normalizedRotation = ((_currentRotation % 360) + 360) % 360;
    final newBpm = (normalizedRotation / 360 * 599 + 1).round();
    ref.read(metronomeProvider.notifier).setTempoDirectly(newBpm.clamp(1, 600));
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    HapticFeedback.vibrate();
  }

  double _getAngle(Offset position, {double? size}) {
    // Use provided size or default to 140 (half of 280)
    final halfSize = (size ?? 280) / 2;
    final dx = position.dx - halfSize;
    final dy = position.dy - halfSize;
    return (math.atan2(dy, dx) * 180 / math.pi) +
        90; // Convert to degrees, 0 at top
  }

  void _showTempoDialog(BuildContext context, MetronomeNotifier metronome) {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      builder: (context) =>
          TempoChangeDialog(bpm: ref.read(metronomeProvider).bpm),
    );
  }
}

class _RotaryDial extends StatelessWidget {
  final double size;
  final int bpm;
  final VoidCallback onTap;

  const _RotaryDial({
    required this.size,
    required this.bpm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MonoPulseColors.surface,
          border: Border.all(color: MonoPulseColors.borderSubtle, width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring (visual indicator of BPM position)
            _ProgressRing(size: size, bpm: bpm),

            // Handle/dot on the edge
            _RotateHandle(size: size, bpm: bpm),
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double size;
  final int bpm;

  const _ProgressRing({required this.size, required this.bpm});

  @override
  Widget build(BuildContext context) {
    final normalizedBpm = (bpm - 1) / 599; // 0-1 range
    final strokeWidth = size * 0.04; // 4% of size

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: normalizedBpm,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _RingPainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = MonoPulseColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = MonoPulseColors.accentOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RotateHandle extends StatelessWidget {
  final double size;
  final int bpm;

  const _RotateHandle({required this.size, required this.bpm});

  @override
  Widget build(BuildContext context) {
    final normalizedBpm = (bpm - 1) / 599; // 0-1 range
    final angle = normalizedBpm * 360 * (math.pi / 180); // Convert to radians
    final handleSize = size * 0.06; // 6% of dial size

    return Transform.rotate(
      angle: angle - math.pi / 2, // Start from top
      child: Container(
        margin: EdgeInsets.all(size * 0.04),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: MonoPulseColors.accentOrange,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _BpmDisplay extends StatelessWidget {
  final int bpm;
  final double size;

  const _BpmDisplay({required this.bpm, required this.size});

  @override
  Widget build(BuildContext context) {
    // Scale font sizes based on circle size
    final bpmFontSize = size * 0.28; // 28% of circle size
    final labelFontSize = size * 0.055; // 5.5% of circle size

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$bpm',
          style: TextStyle(
            fontSize: bpmFontSize,
            fontWeight: MonoPulseTypography.bold,
            color: MonoPulseColors.textHighEmphasis,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        SizedBox(height: size * 0.02),
        Text(
          'bpm',
          style: MonoPulseTypography.bodyLarge.copyWith(
            color: MonoPulseColors.textTertiary,
            fontWeight: MonoPulseTypography.medium,
            fontSize: labelFontSize,
          ),
        ),
      ],
    );
  }
}

class _TickMarks extends StatelessWidget {
  final double size;

  const _TickMarks({required this.size});

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
    final radius = canvasSize.width / 2 - 20;

    // Tick mark paint
    final tickPaint = Paint()
      ..color = MonoPulseColors.borderDefault
      ..strokeWidth = 1;

    // Label paint
    final labelPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Draw tick marks every 30 BPM (12 marks for 360 degrees)
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * (math.pi / 180); // Start from top
      final isMajor = i % 3 == 0; // Every 90 degrees (60, 120, 180, etc.)

      final tickLength = isMajor ? size * 0.03 : size * 0.02;
      final x1 = center.dx + (radius - tickLength) * math.cos(angle);
      final y1 = center.dy + (radius - tickLength) * math.sin(angle);
      final x2 = center.dx + radius * math.cos(angle);
      final y2 = center.dy + radius * math.sin(angle);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        tickPaint
          ..color = isMajor
              ? MonoPulseColors.borderDefault
              : MonoPulseColors.borderSubtle,
      );

      // Draw labels for major ticks (60, 120, 180, 240, 300, 360)
      if (isMajor) {
        final bpm = (i / 12 * 599 + 1).round();
        final labelRadius = radius - size * 0.08;
        final labelX = center.dx + labelRadius * math.cos(angle);
        final labelY = center.dy + labelRadius * math.sin(angle);

        labelPaint.text = TextSpan(
          text: '$bpm',
          style: TextStyle(
            fontSize: size * 0.045,
            color: MonoPulseColors.textTertiary,
          ),
        );
        labelPaint.layout();
        labelPaint.paint(
          canvas,
          Offset(labelX - labelPaint.width / 2, labelY - labelPaint.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
