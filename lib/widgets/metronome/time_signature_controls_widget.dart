import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../models/time_signature.dart';

/// Time Signature Controls widget - Preset buttons for common time signatures
/// Replaces dropdowns with intuitive preset chips
class TimeSignatureControlsWidget extends ConsumerWidget {
  const TimeSignatureControlsWidget({super.key});

  // Common time signature presets
  static final List<TimeSignature> presets = [
    const TimeSignature(numerator: 4, denominator: 4), // Common time
    const TimeSignature(numerator: 3, denominator: 4), // Waltz
    const TimeSignature(numerator: 6, denominator: 8), // Compound duple
    const TimeSignature(numerator: 2, denominator: 4), // March
    const TimeSignature(numerator: 5, denominator: 4), // Odd meter
    const TimeSignature(numerator: 7, denominator: 8), // Odd meter
  ];

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
            const Text(
              'Time Signature',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message:
                  'Defines how many beats are in each measure. Top number = beats per measure, Bottom number = note value that gets one beat.',
              child: Icon(
                Icons.help_outline,
                size: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a common time signature',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((ts) {
                final isSelected = state.timeSignature == ts;
                return ChoiceChip(
                  label: Text('${ts.numerator}/${ts.denominator}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      metronome.setTimeSignature(ts);
                    }
                  },
                  selectedColor: Colors.blue.shade100,
                  labelStyle: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.blue.shade900 : Colors.black87,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Current selection display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Current: ', style: TextStyle(fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '${state.timeSignature.numerator}/${state.timeSignature.denominator}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
