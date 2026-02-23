import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data/metronome_provider.dart';
import '../theme/mono_pulse_theme.dart';
import 'metronome/bpm_controls_widget.dart';
import 'metronome/time_signature_controls_widget.dart';
import 'metronome/accent_pattern_editor_widget.dart';
import 'metronome/frequency_controls_widget.dart';
import 'tap_bpm_widget.dart';

/// Metronome widget - Parent container composing smaller widgets
///
/// Mono Pulse Design (Sprint Fix):
/// - Uses MonoPulseColors throughout
/// - Proper spacing and radius from design system
/// - No Material default colors
class MetronomeWidget extends ConsumerWidget {
  const MetronomeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);

    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      decoration: BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // BPM Display and Control
          const BpmControlsWidget(),

          const SizedBox(height: MonoPulseSpacing.lg),

          // Beat Indicators with Blink Animation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              state.timeSignature.numerator,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: MonoPulseAnimation.durationShort,
                  curve: MonoPulseAnimation.curveCustom,
                  width: state.isPlaying && state.currentBeat == index
                      ? 24
                      : 20,
                  height: state.isPlaying && state.currentBeat == index
                      ? 24
                      : 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.isPlaying && state.currentBeat == index
                        ? (state.accentPattern[index] && state.accentEnabled)
                              ? MonoPulseColors.accentOrange
                              : MonoPulseColors.textSecondary
                        : MonoPulseColors.borderSubtle,
                    border: Border.all(
                      color: state.accentPattern[index]
                          ? MonoPulseColors.accentOrange
                          : MonoPulseColors.borderDefault,
                      width: 2,
                    ),
                    boxShadow: state.isPlaying && state.currentBeat == index
                        ? [
                            BoxShadow(
                              color: MonoPulseColors.accentOrange.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: MonoPulseSpacing.lg),

          // Time Signature Selector
          const TimeSignatureControlsWidget(),

          // Accent Pattern Input
          const AccentPatternEditorWidget(),

          const SizedBox(height: MonoPulseSpacing.lg),

          // Tap BPM Widget
          const TapBPMWidget(),

          const SizedBox(height: MonoPulseSpacing.lg),

          // Sound Controls (ADVANCED)
          const FrequencyControlsWidget(),

          const SizedBox(height: MonoPulseSpacing.lg),

          // Play/Stop Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(state.isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(state.isPlaying ? 'Stop' : 'Start'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: state.isPlaying
                    ? MonoPulseColors.error
                    : MonoPulseColors.success,
                foregroundColor: MonoPulseColors.white,
              ),
              onPressed: metronome.toggle,
            ),
          ),
        ],
      ),
    );
  }
}
