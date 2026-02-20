import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/metronome_provider.dart';

/// Simple metronome widget that can be embedded in other screens
class MetronomeWidget extends ConsumerWidget {
  const MetronomeWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronomeState = ref.watch(metronomeStateProvider);
    final metronomeNotifier = ref.read(metronomeStateProvider.notifier);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BPM Display and Control
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrease BPM
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => metronomeNotifier.setBpm(metronomeState.bpm - 1),
                ),
                // BPM Value
                Expanded(
                  child: Column(
                    children: [
                      const Text('BPM', style: TextStyle(fontSize: 12)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                        ),
                        child: Slider(
                          value: metronomeState.bpm.toDouble(),
                          min: 40,
                          max: 220,
                          divisions: 180,
                          onChanged: (value) => metronomeNotifier.setBpm(value.round()),
                        ),
                      ),
                      Text(
                        '${metronomeState.bpm}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Increase BPM
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => metronomeNotifier.setBpm(metronomeState.bpm + 1),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Beat Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                metronomeState.beatsPerMeasure,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: metronomeState.currentBeat == index
                          ? (index == 0 ? Colors.red : Colors.blue)
                          : Colors.grey.shade300,
                      border: Border.all(
                        color: index == 0 ? Colors.red.shade700 : Colors.blue.shade700,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Time Signature Selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [2, 3, 4, 5, 6, 7].map((beats) {
                final isSelected = metronomeState.beatsPerMeasure == beats;
                return ChoiceChip(
                  label: Text(getTimeSignatureLabel(beats)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      metronomeNotifier.setBeatsPerMeasure(beats);
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Play/Stop Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(metronomeState.isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(metronomeState.isPlaying ? 'Stop' : 'Start'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: metronomeState.isPlaying ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => metronomeNotifier.toggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
