import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/music_mode.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Note Scale Ruler widget for Tuner dial
///
/// Displays 12 chromatic notes around the dial perimeter.
/// TAPPABLE: User taps directly on note names to select them.
class NoteScaleRuler extends ConsumerWidget {
  final double dialSize;

  const NoteScaleRuler({super.key, required this.dialSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);
    final currentMode = allMusicModes[state.musicModeIndex];
    final currentNote = state.note.replaceAll(RegExp(r'\d'), '');
    final currentNoteIndex = _noteNameToIndex(currentNote);

    return SizedBox(
      width: dialSize,
      height: dialSize,
      child: Stack(
        children: [
          // Background painter
          CustomPaint(
            size: Size(dialSize, dialSize),
            painter: _NoteScaleRulerPainter(
              currentNoteIndex: currentNoteIndex,
              scaleIntervals: currentMode.intervals,
              dialSize: dialSize,
            ),
          ),
          // Tappable areas - positioned over each note
          ...List.generate(12, (index) {
            final angleDeg = -90.0 + (index * 30.0);
            final angleRad = angleDeg * (math.pi / 180);
            final radius = dialSize / 2;
            final noteRadius = radius * 1.08;
            final x = radius + noteRadius * math.cos(angleRad);
            final y = radius + noteRadius * math.sin(angleRad);

            return Positioned(
              left: x - 20,
              top: y - 20,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setTargetNoteByIndex(index);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  color: Colors.transparent,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  int _noteNameToIndex(String note) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final idx = notes.indexOf(note);
    return idx >= 0 ? idx : 0;
  }
}

class _NoteScaleRulerPainter extends CustomPainter {
  final int currentNoteIndex;
  final List<int> scaleIntervals;
  final double dialSize;

  _NoteScaleRulerPainter({
    required this.currentNoteIndex,
    required this.scaleIntervals,
    required this.dialSize,
  });

  static const List<String> _notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      final angleDeg = -90.0 + (i * 30.0);
      final angleRad = angleDeg * (math.pi / 180);

      final isInScale = scaleIntervals.contains(i);
      final isCurrentNote = i == currentNoteIndex;

      // COLOR SYSTEM:
      // 1. Orange - Current detected note (where dot is)
      // 2. White - Notes in scale (available but not current)
      // 3. Grey - Notes NOT in scale (unavailable)
      
      Color color;
      double fontSize;
      FontWeight fontWeight;
      double tickLength;
      double tickWidth;
      double opacity;

      if (isCurrentNote) {
        // Current note: BRIGHT ORANGE (always, regardless of scale)
        color = MonoPulseColors.accentOrange;
        fontSize = 16.0;
        fontWeight = MonoPulseTypography.bold;
        tickLength = 14.0;
        tickWidth = 3.0;
        opacity = 1.0;
      } else if (isInScale) {
        // In scale but not current: WHITE (available target)
        color = MonoPulseColors.white;
        fontSize = 13.0;
        fontWeight = MonoPulseTypography.medium;
        tickLength = 10.0;
        tickWidth = 2.0;
        opacity = 0.5;
      } else {
        // Not in scale: GREY (unavailable)
        color = MonoPulseColors.textTertiary;
        fontSize = 11.0;
        fontWeight = MonoPulseTypography.regular;
        tickLength = 6.0;
        tickWidth = 1.0;
        opacity = 0.3;
      }

      final noteRadius = radius * 1.08;
      final x = center.dx + noteRadius * math.cos(angleRad);
      final y = center.dy + noteRadius * math.sin(angleRad);

      textPainter.text = TextSpan(
        text: note,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color.withValues(alpha: opacity),
          letterSpacing: 0.5,
        ),
      );
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );

      // Tick marks
      final tickStartRadius = radius - tickLength;
      final tickEndRadius = radius + 2;

      final x1 = center.dx + tickStartRadius * math.cos(angleRad);
      final y1 = center.dy + tickStartRadius * math.sin(angleRad);
      final x2 = center.dx + tickEndRadius * math.cos(angleRad);
      final y2 = center.dy + tickEndRadius * math.sin(angleRad);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..strokeWidth = tickWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NoteScaleRulerPainter oldDelegate) {
    return oldDelegate.currentNoteIndex != currentNoteIndex ||
        oldDelegate.scaleIntervals != scaleIntervals;
  }
}
