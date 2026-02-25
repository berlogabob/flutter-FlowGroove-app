import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../models/metronome_state.dart';
import '../../theme/mono_pulse_theme.dart';
import 'tempo_change_dialog.dart';

/// Central Tempo Circle widget - Mono Pulse design (Sprint Fix)
///
/// Large rotary dial for tempo adjustment:
/// - Circle diameter ~50-60% screen width
/// - Background: #121212, stroke: 1px #222222
/// - Small dot/handle: #FF5E00 on edge
/// - Tick marks with labels (60, 120, 180 bpm)
/// - Center: BPM number (72-88px Bold) + "bpm" label
///
/// Sprint Fixes:
/// - Increase touch zone (entire circle + 30px around)
/// - Edge dot always matches current BPM (position on scale)
/// - Sensitivity: constant speed, no acceleration (long drag = smooth change)
/// - Scale: thin lines #333333, labels 60/120/180 #8A8A8F
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
  double _cumulativeRotation =
      0; // Track total rotation for constant sensitivity

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

    // Initialize cumulative rotation from current BPM
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bpm = ref.read(metronomeProvider);
      _cumulativeRotation = (bpm.bpm - 1) / 599 * 360;
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

    // Listen to metronome state changes for beat pulse
    ref.listen<MetronomeState>(metronomeProvider, (previous, next) {
      if (next.isPlaying && next.currentBeat != (previous?.currentBeat ?? -1)) {
        _triggerPulse();
      }
    });

    // Use LayoutBuilder to make circle responsive to screen width
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;

        // Adaptive sizing based on screen width
        final isSmallScreen = screenWidth < 375;
        final isMediumScreen = screenWidth >= 375 && screenWidth < 390;

        // Circle diameter: 45-55% of screen width (not fixed 280px)
        final circleSizePercent = isSmallScreen
            ? 0.50
            : (isMediumScreen ? 0.55 : 0.60);
        final circleSize = constraints.maxWidth * circleSizePercent;
        final clampedSize = circleSize.clamp(180.0, 280.0);

        // Reduced padding around circle from 56px to 24px on small screens
        final paddingAroundCircle = isSmallScreen ? 24.0 : 40.0;
        final touchZoneSize = clampedSize + (paddingAroundCircle * 2);

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          // Disable horizontal drag to prevent interference with scroll
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: SizedBox(
              width: touchZoneSize,
              height: touchZoneSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer tick marks and labels (larger area for visual scale)
                  _TickMarks(size: clampedSize, isSmallScreen: isSmallScreen),

                  // Main rotary dial with increased touch zone
                  GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: touchZoneSize,
                      height: touchZoneSize,
                      child: Center(
                        child: AnimatedRotation(
                          turns: _isDragging
                              ? _currentRotation / 360
                              : _cumulativeRotation / 360,
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
                      ),
                    ),
                  ),

                  // Center BPM display with pulse animation (not rotating)
                  IgnorePointer(
                    child: AnimatedScale(
                      scale: _pulseController.isAnimating
                          ? _pulseAnimation.value
                          : 1.0,
                      duration: MonoPulseAnimation.durationShort,
                      curve: MonoPulseAnimation.curveCustom,
                      child: _BpmDisplay(
                        bpm: bpm,
                        size: clampedSize,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
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
      _currentRotation = _cumulativeRotation;
    });
    HapticFeedback.vibrate();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    // Calculate angle change from start position
    final angle = _getAngle(details.localPosition);
    final angleDiff = angle - _startAngle;

    setState(() {
      // Constant sensitivity: 3 degrees = 1 BPM (no acceleration)
      _currentRotation = _cumulativeRotation + angleDiff;
    });

    // Update BPM in real-time with constant sensitivity
    final normalizedRotation = ((_currentRotation % 360) + 360) % 360;
    final newBpm = (normalizedRotation / 360 * 599 + 1).round();
    final clampedBpm = newBpm.clamp(1, 300);

    // Only update if BPM changed
    if (clampedBpm != _startBpm) {
      ref.read(metronomeProvider.notifier).setTempoDirectly(clampedBpm);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    // Update cumulative rotation for smooth continuation
    final normalizedRotation = ((_currentRotation % 360) + 360) % 360;
    setState(() {
      _cumulativeRotation = normalizedRotation;
      _isDragging = false;
    });
    HapticFeedback.vibrate();
  }

  double _getAngle(Offset position, {double? size}) {
    // Use provided size or default to half of touch zone
    final halfSize = (size ?? 170); // Default for ~340px touch zone
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

            // Handle/dot on the edge - always matches current BPM
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
            decoration: const BoxDecoration(
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
  final bool isSmallScreen;

  const _BpmDisplay({
    required this.bpm,
    required this.size,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    // Scale font sizes based on circle size
    // BPM text: 60px on small screens, 72px on large
    final bpmFontSize = size * (isSmallScreen ? 0.28 : 0.32);
    // "bpm" label: 14px instead of 18px on small screens
    final labelFontSize = size * (isSmallScreen ? 0.045 : 0.055);

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
  final bool isSmallScreen;

  const _TickMarks({required this.size, this.isSmallScreen = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TickMarksPainter(size: size, isSmallScreen: isSmallScreen),
      ),
    );
  }
}

class _TickMarksPainter extends CustomPainter {
  final double size;
  final bool isSmallScreen;

  _TickMarksPainter({required this.size, this.isSmallScreen = false});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = canvasSize.width / 2 - 20;

    // Tick mark paint - thin lines #333333
    final tickPaint = Paint()
      ..color = MonoPulseColors
          .borderDefault // #333333
      ..strokeWidth = 1;

    // Label paint - labels #8A8A8F
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
              ? MonoPulseColors
                    .borderDefault // #333333
              : MonoPulseColors.borderSubtle, // #222222
      );

      // Draw labels for major ticks (60, 120, 180, 240, 300, 360)
      // Labels in #8A8A8F (textTertiary)
      if (isMajor) {
        final bpm = (i / 12 * 599 + 1).round();
        final labelRadius = radius - size * 0.08;
        final labelX = center.dx + labelRadius * math.cos(angle);
        final labelY = center.dy + labelRadius * math.sin(angle);

        labelPaint.text = TextSpan(
          text: '$bpm',
          style: TextStyle(
            fontSize: size * (isSmallScreen ? 0.035 : 0.045),
            color: MonoPulseColors.textTertiary, // #8A8A8F
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
