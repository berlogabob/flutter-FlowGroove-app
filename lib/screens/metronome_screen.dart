import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/metronome_widget.dart';

/// Full screen metronome - MVP version
class MetronomeScreen extends ConsumerWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metronome'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
