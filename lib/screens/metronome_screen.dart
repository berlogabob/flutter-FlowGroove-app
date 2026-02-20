import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/metronome_provider.dart';
import '../widgets/metronome_widget.dart';

/// Full screen metronome
class MetronomeScreen extends ConsumerWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(metronomeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metronome'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Visual beat indicator (large)
          Card(
            elevation: 4,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: controller.isPlaying
                    ? (controller.currentBeat == 0
                        ? Colors.red.shade100
                        : Colors.blue.shade100)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: controller.isPlaying
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            controller.currentBeat == 0
                                ? Icons.fiber_manual_record
                                : Icons.circle_outlined,
                            size: 64,
                            color: controller.currentBeat == 0
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Beat ${controller.currentBeat + 1}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: controller.currentBeat == 0
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Press Start',
                        style: TextStyle(fontSize: 24, color: Colors.grey),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Metronome controls
          const MetronomeWidget(),

          const SizedBox(height: 24),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to use',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Adjust BPM using slider or +/- buttons'),
                  const Text('• Select time signature (2/4, 3/4, 4/4, etc.)'),
                  const Text('• Press Start to begin'),
                  const Text('• Visual indicator shows current beat'),
                  const Text('• First beat of measure is accented (red)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
