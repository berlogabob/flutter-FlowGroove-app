import 'package:flutter/material.dart';
import '../models/time_signature.dart';
import '../services/metronome_service.dart';
import 'time_signature_dropdown.dart';

/// Simple metronome widget - with sound controls
class MetronomeWidget extends StatefulWidget {
  const MetronomeWidget({super.key});

  @override
  State<MetronomeWidget> createState() => _MetronomeWidgetState();
}

class _MetronomeWidgetState extends State<MetronomeWidget> {
  final _metronome = MetronomeService();
  final _bpmController = TextEditingController();
  late TextEditingController _accentFreqController;
  late TextEditingController _beatFreqController;
  int _bpm = 120;
  TimeSignature _timeSignature = TimeSignature.commonTime; // 4/4

  @override
  void initState() {
    super.initState();
    _metronome.addListener(_onMetronomeUpdate);
    _bpmController.text = _bpm.toString();
    _accentFreqController = TextEditingController(text: _metronome.accentFrequency.toString());
    _beatFreqController = TextEditingController(text: _metronome.beatFrequency.toString());
    _accentPatternController = TextEditingController(text: _generatePatternString());
  }

  String _generatePatternString() {
    return _metronome.accentPattern.map((isAccent) => isAccent ? 'A' : 'B').join('');
  }

  @override
  void dispose() {
    _bpmController.dispose();
    _accentFreqController.dispose();
    _beatFreqController.dispose();
    _accentPatternController.dispose();
    _metronome.removeListener(_onMetronomeUpdate);
    super.dispose();
  }

  void _onMetronomeUpdate() {
    setState(() {
      _accentPatternController.text = _generatePatternString();
    });
  }

  void _setBpm(int value) {
    final bpm = value.clamp(40, 220);
    setState(() {
      _bpm = bpm;
      _bpmController.text = bpm.toString();
    });
    _metronome.setBpm(bpm);
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
                  onPressed: () => _setBpm(_bpm - 1),
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
                        onChanged: (value) => _setBpm(value.round()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Large BPM display
                          Text(
                            '$_bpm',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Number input field
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _bpmController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                labelText: 'BPM',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (value) {
                                final bpm = int.tryParse(value);
                                if (bpm != null) {
                                  _setBpm(bpm);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _setBpm(_bpm + 1),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Beat Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _timeSignature.numerator,
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

            // Time Signature Selector (two dropdowns)
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text('Time Signature', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TimeSignatureDropdown(
                      value: _timeSignature,
                      onChanged: (ts) {
                        setState(() => _timeSignature = ts);
                        _metronome.setTimeSignature(ts);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Accent Pattern Input
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Accent Pattern', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'A = Accent, B = Regular (e.g., ABBB for 4/4)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _accentPatternController,
                            maxLength: _timeSignature.numerator,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              hintText: 'ABBB',
                              counterText: '',
                            ),
                            onChanged: (pattern) {
                              final boolPattern = pattern.toUpperCase().split('').map((c) {
                                return c == 'A';
                              }).toList();
                              _metronome.setAccentPattern(boolPattern);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Reset to default',
                          onPressed: () {
                            _metronome.updateAccentPatternFromTimeSignature();
                            setState(() {
                              _accentPatternController.text = _generatePatternString();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _timeSignature.numerator,
                        (index) {
                          final isAccent = _metronome.accentPattern[index] ?? false;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isAccent ? Colors.red.shade100 : Colors.blue.shade100,
                                border: Border.all(
                                  color: isAccent ? Colors.red : Colors.blue,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  isAccent ? 'A' : 'B',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAccent ? Colors.red.shade900 : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sound Controls
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Sound Type Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Sound: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _metronome.waveType,
                          items: const [
                            DropdownMenuItem(value: 'sine', child: Text('Sine')),
                            DropdownMenuItem(value: 'square', child: Text('Square')),
                            DropdownMenuItem(value: 'triangle', child: Text('Triangle')),
                            DropdownMenuItem(value: 'sawtooth', child: Text('Sawtooth')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _metronome.setWaveType(value);
                            }
                          },
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

                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Frequencies (Hz)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Accent:', style: TextStyle(fontSize: 12)),
                              TextField(
                                controller: _accentFreqController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.all(4),
                                ),
                                onChanged: (value) {
                                  final freq = double.tryParse(value);
                                  if (freq != null) {
                                    _metronome.setAccentFrequency(freq);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Beat:', style: TextStyle(fontSize: 12)),
                              TextField(
                                controller: _beatFreqController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.all(4),
                                ),
                                onChanged: (value) {
                                  final freq = double.tryParse(value);
                                  if (freq != null) {
                                    _metronome.setBeatFrequency(freq);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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
