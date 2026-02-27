import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import 'tick_marks.dart';

/// Central Dial widget for Tuner screen
///
/// Main visual element - large circle displaying current frequency:
/// - Diameter: 50-60% screen width (280-320px on iPhone)
/// - Background: #121212
/// - Border: 1px #222222 (very thin)
/// - Inside center (vertical layout):
///   - Large text "A4": 72px Bold #EDEDED
///   - Below "440 Hz": 18px Medium #8A8A8F
/// - Edge handle: Small circle diameter 16px, #FF5E00
/// - Surrounded by static tick marks
///
/// INTERACTIVE (Stage 2):
/// - Generate Mode: Drag to rotate and change frequency (1 Hz steps)
/// - Listen Mode: Shows needle indicator for cents deviation
class CentralDial extends ConsumerWidget {
  const CentralDial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);
    final cents = ref.watch(tunerCentsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Circle diameter: 50-60% of screen width, clamped to 280-320px
        final circleSize = constraints.maxWidth * 0.55;
        final clampedSize = circleSize.clamp(280.0, 320.0);

        return Center(
          child: SizedBox(
            width: clampedSize,
            height: clampedSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Tick marks around the circle
                TickMarks(size: clampedSize),

                // Main circle container with gesture detection
                _InteractiveDial(
                  size: clampedSize * 0.85,
                  note: state.note,
                  frequency: state.frequency,
                  cents: cents,
                  mode: state.mode,
                  onFrequencyChanged: (freq) => notifier.updateFrequency(freq),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InteractiveDial extends StatefulWidget {
  final double size;
  final String note;
  final double frequency;
  final int cents;
  final TunerMode mode;
  final Function(double) onFrequencyChanged;

  const _InteractiveDial({
    required this.size,
    required this.note,
    required this.frequency,
    required this.cents,
    required this.mode,
    required this.onFrequencyChanged,
  });

  @override
  State<_InteractiveDial> createState() => _InteractiveDialState();
}

class _InteractiveDialState extends State<_InteractiveDial> {
  double _startAngle = 0;
  bool _isDragging = false;

  // Frequency range
  static const double minFrequency = 20.0;
  static const double maxFrequency = 2000.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MonoPulseColors.surface,
          border: Border.all(color: MonoPulseColors.borderSubtle, width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center frequency/note display
            _FrequencyDisplay(
              note: widget.note,
              frequency: widget.frequency,
              cents: widget.cents,
              mode: widget.mode,
              size: widget.size,
            ),

            // Handle or needle based on mode
            if (widget.mode == TunerMode.generate)
              // Generate mode: rotating handle
              Transform.rotate(
                angle: _angleForFrequency(widget.frequency),
                child: _EdgeHandle(size: widget.size),
              )
            else
              // Listen mode: needle indicator for cents
              _NeedleIndicator(cents: widget.cents, size: widget.size),
          ],
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    HapticFeedback.lightImpact();

    final renderBox = context.findRenderObject() as RenderBox;
    final center = Offset(widget.size / 2, widget.size / 2);
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    _startAngle =
        _angleForFrequency(widget.frequency) -
        (localPosition - center).direction;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final center = Offset(widget.size / 2, widget.size / 2);
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final angle = (localPosition - center).direction + _startAngle;

    // Convert angle to frequency
    final frequency = _frequencyForAngle(angle);
    widget.onFrequencyChanged(frequency);

    // Haptic feedback on frequency change (every 10 Hz)
    if (frequency.round() % 10 == 0) {
      HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    HapticFeedback.lightImpact();
  }

  /// Convert frequency to angle (radians)
  /// Maps 20-2000 Hz to 0-2π (full circle)
  double _angleForFrequency(double frequency) {
    final normalized =
        (frequency - minFrequency) / (maxFrequency - minFrequency);
    // Start from top (-π/2) and go clockwise
    return -math.pi / 2 + normalized * 2 * math.pi;
  }

  /// Convert angle (radians) to frequency
  double _frequencyForAngle(double angle) {
    // Normalize angle to 0-2π range
    var normalizedAngle = angle + math.pi / 2;
    while (normalizedAngle < 0) {
      normalizedAngle += 2 * math.pi;
    }
    while (normalizedAngle >= 2 * math.pi) {
      normalizedAngle -= 2 * math.pi;
    }

    final normalized = normalizedAngle / (2 * math.pi);
    return minFrequency + normalized * (maxFrequency - minFrequency);
  }
}

class _FrequencyDisplay extends StatelessWidget {
  final String note;
  final double frequency;
  final int cents;
  final TunerMode mode;
  final double size;

  const _FrequencyDisplay({
    required this.note,
    required this.frequency,
    required this.cents,
    required this.mode,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Scale font sizes based on circle size
    final noteFontSize = (size * 0.25).clamp(64.0, 80.0);
    final subFontSize = (size * 0.065).clamp(16.0, 20.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large note display (e.g., "A4") - 72px Bold
        Text(
          note,
          style: TextStyle(
            fontSize: noteFontSize,
            fontWeight: MonoPulseTypography.bold,
            color: MonoPulseColors.textHighEmphasis,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        // Hz label or cents display based on mode
        if (mode == TunerMode.generate)
          // Generate mode: show frequency
          Text(
            '${frequency.round()} Hz',
            style: MonoPulseTypography.bodyLarge.copyWith(
              color: MonoPulseColors.textTertiary,
              fontWeight: MonoPulseTypography.medium,
              fontSize: subFontSize,
            ),
          )
        else
          // Listen mode: show cents deviation
          _CentsDisplay(cents: cents, fontSize: subFontSize),
      ],
    );
  }
}

class _CentsDisplay extends StatelessWidget {
  final int cents;
  final double fontSize;

  const _CentsDisplay({required this.cents, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    // Color based on how close to zero (in tune)
    Color centsColor;
    if (cents == 0) {
      centsColor = MonoPulseColors.accentOrange;
    } else if (cents.abs() <= 10) {
      centsColor = MonoPulseColors.textHighEmphasis;
    } else if (cents.abs() <= 25) {
      centsColor = MonoPulseColors.textSecondary;
    } else {
      centsColor = MonoPulseColors.textTertiary;
    }

    final sign = cents > 0 ? '+' : '';
    final centsText = cents == 0 ? 'In Tune' : '$sign$cents cents';

    return Text(
      centsText,
      style: MonoPulseTypography.bodyLarge.copyWith(
        color: centsColor,
        fontWeight: MonoPulseTypography.medium,
        fontSize: fontSize,
      ),
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  final double size;

  const _EdgeHandle({required this.size});

  @override
  Widget build(BuildContext context) {
    final handleSize = size * 0.055; // ~16px for 280px circle

    // Position at top edge (12 o'clock position)
    return Transform.translate(
      offset: Offset(0, -(size / 2 - handleSize / 2)),
      child: Container(
        width: handleSize,
        height: handleSize,
        decoration: BoxDecoration(
          color: MonoPulseColors.accentOrange,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _NeedleIndicator extends StatelessWidget {
  final int cents;
  final double size;

  const _NeedleIndicator({required this.cents, required this.size});

  @override
  Widget build(BuildContext context) {
    // Map cents (-50 to +50) to angle (-45° to +45°)
    final normalizedCents = cents.clamp(-50, 50) / 50.0;
    final angle = normalizedCents * (math.pi / 4); // ±45 degrees

    final needleLength = size * 0.35;
    final needleWidth = size * 0.015;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: MonoPulseAnimation.curveCustom,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: needleWidth,
          height: needleLength,
          decoration: BoxDecoration(
            color: MonoPulseColors.accentOrange,
            borderRadius: BorderRadius.circular(needleWidth / 2),
          ),
        ),
      ),
    );
  }
}
