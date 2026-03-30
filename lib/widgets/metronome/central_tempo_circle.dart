/// Central tempo circle widget
///
/// Rotary dial for BPM control with pulse animation.
/// Features:
/// - Drag up/down to adjust BPM
/// - Always-visible BPM handle
/// - Tick marks with labels (60, 120, 180, 240, 300)
/// - Pulse animation on beats
/// - Constant sensitivity (3° = 1 BPM)
/// - Adaptive sizing
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../providers/metronome_selective_providers.dart';

/// Central tempo circle with rotary BPM control
class CentralTempoCircle extends ConsumerStatefulWidget {
  const CentralTempoCircle({super.key});

  @override
  ConsumerState<CentralTempoCircle> createState() => _CentralTempoCircleState();
}

class _CentralTempoCircleState extends ConsumerState<CentralTempoCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double _rotationOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
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

    // Trigger pulse animation on beat
    ref.listen<int>(metronomeCurrentBeatProvider, (previous, next) {
      if (state.isPlaying) {
        _triggerPulse();
      }
    });

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onTap: () => _showBpmInput(context, notifier),
      child: SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: CustomPaint(
                painter: TempoDialPainter(
                  bpm: state.bpm.toDouble(),
                  isPlaying: state.isPlaying,
                  rotationOffset: _rotationOffset,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.bpm.toString(),
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: state.isPlaying
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'BPM',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final notifier = ref.read(metronomeProvider.notifier);
    final delta = details.delta.dy;

    // Constant sensitivity: 3° = 1 BPM
    final newBpm = (ref.read(metronomeProvider).bpm - delta).clamp(10, 260);
    notifier.setBpm(newBpm.round());

    // Update rotation offset for visual feedback
    setState(() {
      _rotationOffset = (260 - newBpm) / 250 * 2 * math.pi;
    });

    // Haptic feedback on BPM change
    HapticFeedback.lightImpact();
  }

  void _showBpmInput(BuildContext context, MetronomeNotifier notifier) {
    final controller = TextEditingController(
      text: ref.read(metronomeProvider).bpm.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set BPM'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (value) {
            final bpm = int.tryParse(value);
            if (bpm != null) {
              notifier.setBpm(bpm.clamp(10, 260));
            }
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
                notifier.setBpm(bpm.clamp(10, 260));
              }
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0.0);
  }
}

/// Custom painter for tempo dial
class TempoDialPainter extends CustomPainter {
  final double bpm;
  final bool isPlaying;
  final double rotationOffset;

  TempoDialPainter({
    required this.bpm,
    required this.isPlaying,
    required this.rotationOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw outer ring
    final ringPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw tick marks
    _drawTickMarks(canvas, center, radius);

    // Draw BPM handle
    _drawBpmHandle(canvas, center, radius);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 2;

    final labelPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Major ticks at 60, 120, 180, 240, 300
    final majorTicks = [60, 120, 180, 240, 300];

    for (final tick in majorTicks) {
      final angle = _bpmToAngle(tick.toDouble()) + rotationOffset - math.pi / 2;
      final startX = center.dx + (radius - 10) * math.cos(angle);
      final startY = center.dy + (radius - 10) * math.sin(angle);
      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);

      // Draw label
      final labelX = center.dx + (radius - 30) * math.cos(angle);
      final labelY = center.dy + (radius - 30) * math.sin(angle);

      labelPaint.text = TextSpan(
        text: tick.toString(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(labelX - labelPaint.width / 2, labelY - labelPaint.height / 2),
      );
    }
  }

  void _drawBpmHandle(Canvas canvas, Offset center, double radius) {
    final angle = _bpmToAngle(bpm) + rotationOffset - math.pi / 2;
    final handleX = center.dx + radius * math.cos(angle);
    final handleY = center.dy + radius * math.sin(angle);

    // Draw handle circle
    final handlePaint = Paint()
      ..color = isPlaying ? Colors.orange : Colors.grey
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(handleX, handleY), 8, handlePaint);

    // Draw glow effect when playing
    if (isPlaying) {
      final glowPaint = Paint()
        ..color = Colors.orange.withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(handleX, handleY), 12, glowPaint);
    }
  }

  double _bpmToAngle(double bpm) {
    // Map BPM 10.0-260.0 to angle 0-2π
    return (260.0 - bpm) / 250.0 * 2 * math.pi;
  }

  @override
  bool shouldRepaint(TempoDialPainter oldDelegate) {
    return bpm != oldDelegate.bpm ||
        isPlaying != oldDelegate.isPlaying ||
        rotationOffset != oldDelegate.rotationOffset;
  }
}
