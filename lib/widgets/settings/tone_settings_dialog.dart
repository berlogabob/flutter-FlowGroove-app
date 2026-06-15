/// Tone settings dialog
///
/// Fullscreen dialog for configuring metronome tone settings.
/// Provides:
/// - Preset selector (5 presets)
/// - Frequency matrix (6 sliders)
/// - Wave type selector (4 types)
/// - Volume control
/// - Test sound button
/// - Reset to defaults
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/global_tone_config_provider.dart';
import '../../models/metronome_tone_config.dart';

/// Fullscreen tone settings dialog
class ToneSettingsDialog extends ConsumerStatefulWidget {
  const ToneSettingsDialog({super.key});

  @override
  ConsumerState<ToneSettingsDialog> createState() => _ToneSettingsDialogState();
}

class _ToneSettingsDialogState extends ConsumerState<ToneSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final toneConfig = ref.watch(globalToneConfigProvider);
    final notifier = ref.read(globalToneConfigProvider.notifier);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tone Settings'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _showResetDialog(notifier),
              tooltip: 'Reset to Defaults',
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Done',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Preset Selector
            _PresetSelector(
              currentPreset: _getCurrentPresetName(toneConfig),
              onSelect: (preset) => notifier.setPreset(preset),
            ),

            const SizedBox(height: 24),

            // Frequency Matrix
            _FrequencyMatrix(config: toneConfig, notifier: notifier),

            const SizedBox(height: 24),

            // Wave Type Selector
            _WaveTypeSelector(
              currentWaveType: toneConfig.waveType,
              onWaveTypeChanged: notifier.setWaveType,
            ),

            const SizedBox(height: 24),

            // Volume Control
            _VolumeControl(
              currentVolume: toneConfig.volume,
              onVolumeChanged: notifier.setVolume,
            ),

            const SizedBox(height: 32),

            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _playTestSound(notifier),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test Sound'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentPresetName(MetronomeToneConfig config) {
    // Try to match current config to a preset
    final presets = {
      'Classic': MetronomeToneConfig.classic(),
      'Subtle': MetronomeToneConfig.subtle(),
      'Extreme': MetronomeToneConfig.extreme(),
      'Wood Block': MetronomeToneConfig.woodBlock(),
      'Electronic': MetronomeToneConfig.electronic(),
    };

    for (final entry in presets.entries) {
      if (config == entry.value) {
        return entry.key;
      }
    }

    return 'Custom';
  }

  void _showResetDialog(ToneConfigNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset all tone settings to the Classic preset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.resetToDefault();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _playTestSound(ToneConfigNotifier notifier) async {
    // Play test sound using current configuration
    await notifier.testCurrentConfig();

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test sound played'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}

/// Preset selector widget
class _PresetSelector extends StatelessWidget {
  const _PresetSelector({
    required this.currentPreset,
    required this.onSelect,
  });

  final String currentPreset;
  final Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Presets',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MetronomeToneConfig.availablePresets.map((preset) {
            final isSelected = preset == currentPreset;
            return ChoiceChip(
              label: Text(preset),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onSelect(preset);
                }
              },
            );
          }).toList(),
        ),
        if (currentPreset == 'Custom') ...[
          const SizedBox(height: 8),
          const Text(
            'Custom configuration',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}

/// Frequency matrix widget with 6 sliders
class _FrequencyMatrix extends StatelessWidget {
  const _FrequencyMatrix({
    required this.config,
    required this.notifier,
  });

  final MetronomeToneConfig config;
  final ToneConfigNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequencies',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _FrequencySlider(
          label: 'Main Beat (Regular)',
          value: config.mainRegularFreq,
          min: 200,
          max: 4000,
          onChanged: (value) => notifier.updateFrequency(
            frequencyType: 'mainRegular',
            value: value,
          ),
        ),
        _FrequencySlider(
          label: 'Main Beat (Accented)',
          value: config.mainAccentFreq,
          min: 200,
          max: 4000,
          onChanged: (value) => notifier.updateFrequency(
            frequencyType: 'mainAccent',
            value: value,
          ),
        ),
        _FrequencySlider(
          label: 'Sub Beat (Regular)',
          value: config.subRegularFreq,
          min: 200,
          max: 4000,
          onChanged: (value) => notifier.updateFrequency(
            frequencyType: 'subRegular',
            value: value,
          ),
        ),
        _FrequencySlider(
          label: 'Sub Beat (Accented)',
          value: config.subAccentFreq,
          min: 200,
          max: 4000,
          onChanged: (value) => notifier.updateFrequency(
            frequencyType: 'subAccent',
            value: value,
          ),
        ),
        _FrequencySlider(
          label: 'Divider (Regular)',
          value: config.dividerRegularFreq,
          min: 200,
          max: 4000,
          onChanged: (value) => notifier.updateFrequency(
            frequencyType: 'dividerRegular',
            value: value,
          ),
        ),
        _FrequencySlider(
          label: 'Divider (Accented)',
          value: config.dividerAccentFreq,
          min: 200,
          max: 4000,
          onChanged: (value) => notifier.updateFrequency(
            frequencyType: 'dividerAccent',
            value: value,
          ),
        ),
      ],
    );
  }
}

/// Individual frequency slider
class _FrequencySlider extends StatelessWidget {
  const _FrequencySlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                '${value.round()} Hz',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: 38,
            label: '${value.round()} Hz',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Wave type selector
class _WaveTypeSelector extends StatelessWidget {
  const _WaveTypeSelector({
    required this.currentWaveType,
    required this.onWaveTypeChanged,
  });

  final String currentWaveType;
  final Function(String) onWaveTypeChanged;

  @override
  Widget build(BuildContext context) {
    final waveTypes = [
      {'name': 'Sine', 'icon': Icons.waves, 'desc': 'Smooth, pure tone'},
      {'name': 'Square', 'icon': Icons.square, 'desc': 'Harsh, digital'},
      {'name': 'Triangle', 'icon': Icons.change_history, 'desc': 'Soft, mellow'},
      {'name': 'Sawtooth', 'icon': Icons.trending_up, 'desc': 'Bright, edgy'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wave Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...waveTypes.map((wave) {
          final waveName = wave['name'] as String;
          // ignore: deprecated_member_use
          return RadioListTile<String>(
            title: Text(waveName),
            subtitle: Text(wave['desc'] as String),
            value: waveName.toLowerCase(),
            // ignore: deprecated_member_use
            groupValue: currentWaveType.toLowerCase(),
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) {
                onWaveTypeChanged(value);
              }
            },
            secondary: Icon(wave['icon'] as IconData),
          );
        }),
      ],
    );
  }
}

/// Volume control slider
class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.currentVolume,
    required this.onVolumeChanged,
  });

  final double currentVolume;
  final Function(double) onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Volume',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.volume_down, size: 20),
            Expanded(
              child: Slider(
                value: currentVolume,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: '${(currentVolume * 100).round()}%',
                onChanged: onVolumeChanged,
              ),
            ),
            const Icon(Icons.volume_up, size: 20),
            Text(
              '${(currentVolume * 100).round()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
