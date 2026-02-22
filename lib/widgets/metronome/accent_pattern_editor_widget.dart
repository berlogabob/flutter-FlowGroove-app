import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';

/// Accent Pattern Editor widget - Visual toggle buttons for each beat
/// Replaces text input with intuitive toggle buttons (Accent/Regular)
class AccentPatternEditorWidget extends ConsumerWidget {
  const AccentPatternEditorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Accent Pattern',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Reset to default',
                  onPressed: () {
                    metronome.updateAccentPatternFromTimeSignature();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to toggle Accent (strong) or Regular (weak) for each beat',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Toggle buttons for each beat
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(state.timeSignature.numerator, (index) {
                final isAccent = state.accentPattern[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      // Beat number
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Toggle button
                      InkWell(
                        onTap: () {
                          final newPattern = List<bool>.from(
                            state.accentPattern,
                          );
                          newPattern[index] = !newPattern[index];
                          metronome.setAccentPattern(newPattern);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isAccent
                                ? Colors.red.shade100
                                : Colors.blue.shade100,
                            border: Border.all(
                              color: isAccent ? Colors.red : Colors.blue,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isAccent ? Icons.star : Icons.circle_outlined,
                            color: isAccent
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Label
                      Text(
                        isAccent ? 'Accent' : 'Regular',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isAccent
                              ? Colors.red.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
