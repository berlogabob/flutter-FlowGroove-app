import 'package:flutter/material.dart';
import '../services/metronome_service.dart';

/// Simple metronome widget - with sound controls
class MetronomeWidget extends StatefulWidget {
  const MetronomeWidget({super.key});

  @override
  State<MetronomeWidget> createState() => _MetronomeWidgetState();
}

class _MetronomeWidgetState extends State<MetronomeWidget> {
  final _metronome = MetronomeService();
  int _bpm = 120;
  int _beatsPerMeasure = 4;

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
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() => _bpm = (_bpm - 1).clamp(40, 220));
                    _metronome.setBpm(_bpm);
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text('BPM', style: TextStyle(fontSize: 12)),
                      Slider(
                        value: _bpm.toDouble(),
                        min: 40,
                        max: 220,
                        divisions: 180,
                        onChanged: (value) {
                          setState(() => _bpm = value.round());
                          _metronome.setBpm(_bpm);
                        },
                      ),
                      Text(
                        '$_bpm',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() => _bpm = (_bpm + 1).clamp(40, 220));
                    _metronome.setBpm(_bpm);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Beat Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _beatsPerMeasure,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _metronome.isPlaying && _metronome.currentBeat == index
                          ? (index == 0 && _metronome.accentEnabled ? Colors.red : Colors.blue)
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

            // Time Signature Selector (simplified - just numerator for now)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [2, 3, 4, 5, 6, 7].map((beats) {
                final isSelected = _beatsPerMeasure == beats;
                return ChoiceChip(
                  label: Text('$beats/4'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _beatsPerMeasure = beats);
                      _metronome.setBeatsPerMeasure(beats);
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Sound Controls
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Wave Type Selector
                    Row(
                      children: [
                        const Text('Wave: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'sine', label: Text('Sine')),
                              ButtonSegment(value: 'square', label: Text('Square')),
                            ],
                            selected: {_metronome.waveType},
                            onSelectionChanged: (Set<String> selected) {
                              _metronome.setWaveType(selected.first);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Volume Slider
                    Row(
                      children: [
                        const Icon(Icons.volume_up, size: 20),
                        Expanded(
                          child: Slider(
                            value: _metronome.volume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            label: '${(_metronome.volume * 100).round()}%',
                            onChanged: (value) {
                              _metronome.setVolume(value);
                            },
                          ),
                        ),
                      ],
                    ),

                    // Accent Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Accent on beat 1', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Higher pitch on first beat', style: TextStyle(fontSize: 12)),
                      value: _metronome.accentEnabled,
                      onChanged: (value) {
                        _metronome.setAccentEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Play/Stop Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(_metronome.isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_metronome.isPlaying ? 'Stop' : 'Start'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: _metronome.isPlaying ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _metronome.toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
