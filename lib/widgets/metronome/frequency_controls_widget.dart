import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';

/// Frequency Controls widget - Sound settings (ADVANCED)
/// Contains: Wave type selector, volume slider, accent toggle, frequency inputs
/// Now collapsible to hide advanced settings from casual users
class FrequencyControlsWidget extends ConsumerStatefulWidget {
  const FrequencyControlsWidget({super.key});

  @override
  ConsumerState<FrequencyControlsWidget> createState() =>
      _FrequencyControlsWidgetState();
}

class _FrequencyControlsWidgetState
    extends ConsumerState<FrequencyControlsWidget> {
  late TextEditingController _accentFreqController;
  late TextEditingController _beatFreqController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(metronomeProvider);
    _accentFreqController = TextEditingController(
      text: state.accentFrequency.toString(),
    );
    _beatFreqController = TextEditingController(
      text: state.beatFrequency.toString(),
    );
  }

  @override
  void didUpdateWidget(FrequencyControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = ref.read(metronomeProvider);
    if (_accentFreqController.text != state.accentFrequency.toString()) {
      _accentFreqController.text = state.accentFrequency.toString();
    }
    if (_beatFreqController.text != state.beatFrequency.toString()) {
      _beatFreqController.text = state.beatFrequency.toString();
    }
  }

  @override
  void dispose() {
    _accentFreqController.dispose();
    _beatFreqController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Collapsible Advanced Settings Header
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Advanced Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.tune, size: 20),
                  ],
                ),
              ),
            ),

            // Collapsible Content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),

                  // Tone Type Selector with User-Friendly Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Tone: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: state.waveType,
                        items: const [
                          DropdownMenuItem(
                            value: 'sine',
                            child: Text('Smooth (Sine)'),
                          ),
                          DropdownMenuItem(
                            value: 'square',
                            child: Text('Sharp (Square)'),
                          ),
                          DropdownMenuItem(
                            value: 'triangle',
                            child: Text('Soft (Triangle)'),
                          ),
                          DropdownMenuItem(
                            value: 'sawtooth',
                            child: Text('Bright (Sawtooth)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            metronome.setWaveType(value);
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
                          value: state.volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: '${(state.volume * 100).round()}%',
                          onChanged: (value) {
                            metronome.setVolume(value);
                          },
                        ),
                      ),
                    ],
                  ),

                  // Accent Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Accent on beat 1',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Higher pitch on first beat',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: state.accentEnabled,
                    onChanged: (value) {
                      metronome.setAccentEnabled(value);
                    },
                  ),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Frequencies (Hz)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Accent:',
                              style: TextStyle(fontSize: 12),
                            ),
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
                                  metronome.setAccentFrequency(freq);
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
                                  metronome.setBeatFrequency(freq);
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
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}
