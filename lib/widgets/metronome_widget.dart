import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui/metronome_provider.dart';
import 'metronome/bpm_controls_widget.dart';
import 'metronome/time_signature_controls_widget.dart';
import 'metronome/accent_pattern_editor_widget.dart';
import 'metronome/frequency_controls_widget.dart';
import 'tap_bpm_widget.dart';

/// Metronome widget - Parent container composing smaller widgets
///
/// Composed of:
/// - [BpmControlsWidget] - BPM slider and input
/// - [TimeSignatureControlsWidget] - Time signature dropdown
/// - [AccentPatternEditorWidget] - Accent pattern input
/// - [FrequencyControlsWidget] - Sound settings (ADVANCED)
class MetronomeWidget extends ConsumerWidget {
  const MetronomeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BPM Display and Control
            const BpmControlsWidget(),

            const SizedBox(height: 16),

            // Beat Indicators with Blink Animation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                state.timeSignature.numerator,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
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
                                ? Colors.red
                                : Colors.blue
                          : Colors.grey.shade300,
                      border: Border.all(
                        color: state.accentPattern[index]
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                        width: 2,
                      ),
                      boxShadow: state.isPlaying && state.currentBeat == index
                          ? [
                              BoxShadow(
                                color:
                                    ((state.accentPattern[index] &&
                                                state.accentEnabled)
                                            ? Colors.red
                                            : Colors.blue)
                                        .withOpacity(0.4),
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

            const SizedBox(height: 16),

            // Time Signature Selector
            const TimeSignatureControlsWidget(),

            // Accent Pattern Input
            const AccentPatternEditorWidget(),

            const SizedBox(height: 16),

            // Tap BPM Widget
            const TapBPMWidget(),

            const SizedBox(height: 16),

            // Sound Controls (ADVANCED)
            const FrequencyControlsWidget(),

            const SizedBox(height: 16),

            // Play/Stop Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(state.isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(state.isPlaying ? 'Stop' : 'Start'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: state.isPlaying ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: metronome.toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
