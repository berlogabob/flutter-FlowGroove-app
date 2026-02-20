import 'package:flutter/material.dart';
import '../services/metronome_service.dart';
import '../widgets/metronome_widget.dart';

/// Full screen metronome - MVP version
class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final _metronome = MetronomeService();

  @override
  void initState() {
    super.initState();
    _metronome.addListener(_onMetronomeUpdate);
  }

  @override
  void dispose() {
    _metronome.removeListener(_onMetronomeUpdate);
    super.dispose();
  }

  void _onMetronomeUpdate() {
    setState(() {
      // Trigger rebuild
    });
  }

  @override
  Widget build(BuildContext context) {
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
