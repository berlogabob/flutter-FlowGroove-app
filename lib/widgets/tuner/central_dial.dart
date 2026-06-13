import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import 'note_scale_ruler.dart';
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
                // Note scale ruler around the perimeter
                const NoteScaleRuler(dialSize: 320),

                // Tick marks around the circle
                TickMarks(size: clampedSize),

                // Main circle container with gesture detection
                _InteractiveDial(
                  size: clampedSize * 0.85,
                  note: state.note,
                  frequency: state.frequency,
                  cents: cents,
                  mode: state.mode,
                  hasValidPitch: state.hasValidPitch,
                  isInTune: state.isInTune,
                  isListening: state.isListening,
                  isStarting: state.isStarting,
                  signalLabel: switch (state.signalState.name) {
                    'noSignal' => 'No signal',
                    'unstable' => 'Hold the note steady',
                    _ => 'Tap Listen to start',
                  },
                  targetNoteIndex: state.mode == TunerMode.listen
                      ? (() {
                          final noteName = state.note.replaceAll(
                            RegExp(r'\d'),
                            '',
                          );
                          final idx = _noteNameToIndex(noteName);
                          debugPrint(
                            '🎵 Dial: state.note=${state.note}, noteName=$noteName, index=$idx',
                          );
                          return idx;
                        }).call()
                      : null,
                  onFrequencyChanged: notifier.updateFrequency,
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
  final bool hasValidPitch;
  final bool isInTune;
  final bool isListening;
  final bool isStarting;
  final String signalLabel;
  final int? targetNoteIndex; // For manual mode: which note is selected (0-11)
  final void Function(double) onFrequencyChanged;

  const _InteractiveDial({
    required this.size,
    required this.note,
    required this.frequency,
    required this.cents,
    required this.mode,
    required this.hasValidPitch,
    required this.isInTune,
    required this.isListening,
    required this.isStarting,
    required this.signalLabel,
    this.targetNoteIndex,
    required this.onFrequencyChanged,
  });

  @override
  State<_InteractiveDial> createState() => _InteractiveDialState();
}

class _InteractiveDialState extends State<_InteractiveDial> {
  double _startAngle = 0;
  bool _isDragging = false;

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
              hasValidPitch: widget.hasValidPitch,
              isInTune: widget.isInTune,
              isListening: widget.isListening,
              isStarting: widget.isStarting,
              signalLabel: widget.signalLabel,
            ),

            // Radial gradient overlay for lens effect
            _RadialGradientOverlay(size: widget.size),

            // Handle or needle based on mode
            if (widget.mode == TunerMode.generate)
              // Generate mode: rotating handle based on frequency
              Transform.rotate(
                angle: _angleForFrequency(widget.frequency),
                child: _EdgeHandle(size: widget.size),
              )
            else if (widget.mode == TunerMode.listen &&
                widget.targetNoteIndex != null)
              // Manual mode: handle points to selected note position (chromatic)
              Transform.rotate(
                angle: _angleForNoteIndex(widget.targetNoteIndex!),
                child: _EdgeHandle(size: widget.size),
              )
            else if (widget.hasValidPitch)
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

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final localPosition = renderObject.globalToLocal(details.globalPosition);

    // Calculate current note index from frequency (same as note ruler)
    const referenceFrequency = 440.0;
    const referenceNoteIndex = 69;
    final midiNote =
        referenceNoteIndex +
        12 * math.log(widget.frequency / referenceFrequency) / math.ln2;
    final chromaticIndex =
        ((midiNote.round() % 12) + 12) % 12; // Ensure positive
    final currentAngle = _angleForNoteIndex(chromaticIndex);

    _startAngle = currentAngle - (localPosition - center).direction;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final localPosition = renderObject.globalToLocal(details.globalPosition);
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
  /// MUST match note_scale_ruler.dart: -90° + (chromaticIndex * 30°)
  double _angleForFrequency(double frequency) {
    // Convert frequency to MIDI note number
    const referenceFrequency = 440.0; // A4
    const referenceNoteIndex = 69; // A4 in MIDI
    final midiNote =
        referenceNoteIndex +
        12 * math.log(frequency / referenceFrequency) / math.ln2;

    // Get chromatic index (0-11, C-B), ensure positive
    final chromaticIndex = ((midiNote.round() % 12) + 12) % 12;

    // Match note ruler: -90° + (index * 30°)
    return (-math.pi / 2) + (chromaticIndex * 30.0) * (math.pi / 180);
  }

  /// Convert angle (radians) to frequency
  /// MUST match note_scale_ruler.dart: angle = -90° + (index * 30°)
  double _frequencyForAngle(double angle) {
    // Reverse the ruler formula: angle = -90° + (index * 30°)
    // So: index = (angle + 90°) / 30°
    final angleDeg = angle * 180 / math.pi;
    final chromaticIndex = (((angleDeg + 90) / 30).round() % 12 + 12) % 12;

    // Convert note index to frequency (4th octave)
    const noteFrequencies = [
      261.63, // C4
      277.18, // C#4
      293.66, // D4
      311.13, // D#4
      329.63, // E4
      349.23, // F4
      369.99, // F#4
      392.00, // G4
      415.30, // G#4
      440.00, // A4
      466.16, // A#4
      493.88, // B4
    ];

    return noteFrequencies[chromaticIndex];
  }

  /// Convert note chromatic index (0-11) to angle for dial handle
  /// MUST match note_scale_ruler.dart: -90° + (index * 30°)
  double _angleForNoteIndex(int noteIndex) {
    // Match the note ruler exactly: -90° + (index * 30°)
    return (-math.pi / 2) + (noteIndex * 30.0) * (math.pi / 180);
  }
}

class _FrequencyDisplay extends StatelessWidget {
  final String note;
  final double frequency;
  final int cents;
  final TunerMode mode;
  final double size;
  final bool hasValidPitch;
  final bool isInTune;
  final bool isListening;
  final bool isStarting;
  final String signalLabel;

  const _FrequencyDisplay({
    required this.note,
    required this.frequency,
    required this.cents,
    required this.mode,
    required this.size,
    required this.hasValidPitch,
    required this.isInTune,
    required this.isListening,
    required this.isStarting,
    required this.signalLabel,
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
          mode == TunerMode.listen && !hasValidPitch ? '--' : note,
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
        else ...[
          Text(
            hasValidPitch
                ? '${frequency.toStringAsFixed(1)} Hz'
                : isStarting
                ? 'Starting microphone…'
                : signalLabel,
            style: MonoPulseTypography.bodyLarge.copyWith(
              color: MonoPulseColors.textTertiary,
              fontWeight: MonoPulseTypography.medium,
              fontSize: subFontSize,
            ),
          ),
          const SizedBox(height: 4),
          if (hasValidPitch)
            _CentsDisplay(
              cents: cents,
              fontSize: subFontSize,
              isInTune: isInTune,
            ),
        ],
      ],
    );
  }
}

class _CentsDisplay extends StatelessWidget {
  final int cents;
  final double fontSize;
  final bool isInTune;

  const _CentsDisplay({
    required this.cents,
    required this.fontSize,
    required this.isInTune,
  });

  @override
  Widget build(BuildContext context) {
    // Color based on how close to zero (in tune)
    Color centsColor;
    if (isInTune) {
      centsColor = MonoPulseColors.accentOrange;
    } else if (cents.abs() <= 10) {
      centsColor = MonoPulseColors.textHighEmphasis;
    } else if (cents.abs() <= 25) {
      centsColor = MonoPulseColors.textSecondary;
    } else {
      centsColor = MonoPulseColors.textTertiary;
    }

    final sign = cents > 0 ? '+' : '';
    final centsText = isInTune ? 'In Tune' : '$sign$cents cents';

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
        decoration: const BoxDecoration(
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

/// Radial gradient overlay to create lens/physical dial effect
class _RadialGradientOverlay extends StatelessWidget {
  final double size;

  const _RadialGradientOverlay({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            const Color(0xFF1A1A1A), // Lighter center
            const Color(0xFF0D0D0D), // Darker edges
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

/// Convert note name to chromatic index (C=0, C#=1, ... B=11)
int _noteNameToIndex(String noteName) {
  const notes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  final idx = notes.indexOf(noteName);
  return idx >= 0 ? idx : 0;
}
