import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../services/audio/pitch_analysis.dart';
import '../../theme/mono_pulse_theme.dart';
import 'note_scale_ruler.dart';
import 'tick_marks.dart';

/// Angle math shared by the tuner dial's drag tracking and handle rotation.
///
/// Two conventions live side by side and must not be mixed up:
/// - "absolute" angles use the ruler/canvas convention (0°=east, index 0 at
///   -90°=north) — used for placement math and pointer `.direction` deltas;
/// - "rotation" angles are deltas for [Transform.rotate] applied to the edge
///   handle, which is already pre-translated to north, so its rotation is the
///   absolute angle + 90°.
abstract final class TunerDialGeometry {
  static const degreesPerNote = 30.0;

  /// Absolute placement angle (radians) of chromatic index 0-11.
  /// MUST match note_scale_ruler.dart: -90° + (index * 30°).
  static double angleForNoteIndex(int noteIndex) {
    return (-math.pi / 2) + (noteIndex * degreesPerNote) * (math.pi / 180);
  }

  /// Chromatic index (0-11, C-B) of the note nearest to [frequency].
  static int chromaticIndexForFrequency(double frequency, double referenceA4) {
    final midiNote = TunerNoteMath.midiForFrequency(frequency, referenceA4);
    return ((midiNote % 12) + 12) % 12;
  }

  /// Rotation for the north-baked edge handle to point at [noteIndex].
  static double rotationForNoteIndex(int noteIndex) {
    return angleForNoteIndex(noteIndex) + math.pi / 2;
  }

  /// Rotation for the north-baked edge handle to point at the note
  /// nearest to [frequency].
  static double rotationForFrequency(double frequency, double referenceA4) {
    return rotationForNoteIndex(
      chromaticIndexForFrequency(frequency, referenceA4),
    );
  }

  /// Inverse of [angleForNoteIndex]: absolute angle → 4th-octave frequency
  /// at the calibrated A4 reference.
  static double frequencyForAngle(double angle, double referenceA4) {
    final angleDeg = angle * 180 / math.pi;
    final chromaticIndex =
        (((angleDeg + 90) / degreesPerNote).round() % 12 + 12) % 12;
    // 4th octave: MIDI 60 (C4) … 71 (B4)
    return TunerNoteMath.frequencyForMidi(60 + chromaticIndex, referenceA4);
  }
}

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
                    // Below the noise floor but with audible input → ask for
                    // a louder note rather than implying nothing is heard.
                    'noSignal' =>
                      state.inputLevelDb > -70
                          ? 'Too quiet — play one note louder'
                          : 'Play a note',
                    'unstable' => 'Let the note ring',
                    _ => 'Tap Listen to start',
                  },
                  targetNoteIndex: state.mode == TunerMode.listen
                      ? _noteNameToIndex(
                          state.note.replaceAll(RegExp(r'\d'), ''),
                        )
                      : null,
                  referenceA4: state.referenceA4,
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
    required this.referenceA4,
    required this.onFrequencyChanged,
    this.targetNoteIndex,
  });

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
  final double referenceA4;
  final void Function(double) onFrequencyChanged;

  @override
  State<_InteractiveDial> createState() => _InteractiveDialState();
}

class _InteractiveDialState extends State<_InteractiveDial> {
  double _startAngle = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Was an unlabeled interactive node (UX audit F-014). Announce its purpose;
      // exact value is read from the note/frequency readout in the center.
      label: 'Tuning dial, drag to adjust the reference pitch',
      child: GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.mp.surface,
          border: Border.all(color: context.mp.borderSubtle),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Radial gradient lens effect — painted FIRST: its tokens are
            // fully opaque, so anything below it in this Stack is invisible.
            _RadialGradientOverlay(size: widget.size),

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

            // Handle or needle based on mode
            if (widget.mode == TunerMode.generate)
              // Generate mode: rotating handle based on frequency
              Transform.rotate(
                angle: TunerDialGeometry.rotationForFrequency(
                  widget.frequency,
                  widget.referenceA4,
                ),
                child: _EdgeHandle(size: widget.size),
              )
            else if (widget.mode == TunerMode.listen &&
                widget.targetNoteIndex != null)
              // Manual mode: handle points to selected note position (chromatic)
              Transform.rotate(
                angle: TunerDialGeometry.rotationForNoteIndex(
                  widget.targetNoteIndex!,
                ),
                child: _EdgeHandle(size: widget.size),
              )
            else if (widget.hasValidPitch)
              // Listen mode: needle indicator for cents
              _NeedleIndicator(cents: widget.cents, size: widget.size),
          ],
        ),
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
    final currentAngle = TunerDialGeometry.angleForNoteIndex(
      TunerDialGeometry.chromaticIndexForFrequency(
        widget.frequency,
        widget.referenceA4,
      ),
    );

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
    final frequency = TunerDialGeometry.frequencyForAngle(
      angle,
      widget.referenceA4,
    );
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

}

class _FrequencyDisplay extends StatelessWidget {
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
            color: context.mp.textHighEmphasis,
            letterSpacing: -2,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        // Hz label or cents display based on mode
        if (mode == TunerMode.generate)
          // Generate mode: show frequency
          Text(
            '${frequency.round()} Hz',
            style: MonoPulseTypography.bodyLarge.copyWith(
              color: context.mp.textTertiary,
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
              color: context.mp.textTertiary,
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
  const _CentsDisplay({
    required this.cents,
    required this.fontSize,
    required this.isInTune,
  });

  final int cents;
  final double fontSize;
  final bool isInTune;

  @override
  Widget build(BuildContext context) {
    // Color based on how close to zero (in tune)
    Color centsColor;
    if (isInTune) {
      centsColor = MonoPulseColors.accentOrange;
    } else if (cents.abs() <= 10) {
      centsColor = context.mp.textHighEmphasis;
    } else if (cents.abs() <= 25) {
      centsColor = context.mp.textSecondary;
    } else {
      centsColor = context.mp.textTertiary;
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
  const _EdgeHandle({required this.size});

  final double size;

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
  const _NeedleIndicator({required this.cents, required this.size});

  final int cents;
  final double size;

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
  const _RadialGradientOverlay({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          radius: 0.9,
          colors: [
            context.mp.surfaceRaised, // Lighter center
            context.mp.blackSurface, // Darker edges
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
