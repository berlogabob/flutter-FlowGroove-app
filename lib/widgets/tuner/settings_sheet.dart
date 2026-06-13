import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

class TunerSettingsSheet extends ConsumerWidget {
  const TunerSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MonoPulseRadius.large),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MonoPulseSpacing.xl,
              MonoPulseSpacing.lg,
              MonoPulseSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tuner Settings',
                    style: MonoPulseTypography.titleMedium.copyWith(
                      color: MonoPulseColors.textHighEmphasis,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: MonoPulseColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                MonoPulseSpacing.xl,
                MonoPulseSpacing.md,
                MonoPulseSpacing.xl,
                MonoPulseSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.selectedInstrument != null) ...[
                    _SectionLabel('Current Preset'),
                    const SizedBox(height: MonoPulseSpacing.sm),
                    _PresetSummary(
                      instrument: state.selectedInstrument!.name,
                      tuning: state.selectedTuning?.name ?? 'Chromatic',
                    ),
                    const SizedBox(height: MonoPulseSpacing.xl),
                  ],
                  _SettingSlider(
                    label: 'A4 Reference',
                    valueLabel: '${state.referenceA4.round()} Hz',
                    value: state.referenceA4,
                    min: 415,
                    max: 466,
                    divisions: 51,
                    onChanged: notifier.setReferenceA4,
                  ),
                  _SettingSlider(
                    label: 'In-Tune Tolerance',
                    valueLabel: '±${state.centsTolerance} cents',
                    value: state.centsTolerance.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    onChanged: notifier.setCentsTolerance,
                  ),
                  _SettingSlider(
                    label: 'Input Sensitivity',
                    valueLabel: '${state.sensitivity.round()}%',
                    value: state.sensitivity,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: notifier.setSensitivity,
                  ),
                  _SettingSwitch(
                    title: 'Haptic Feedback',
                    subtitle:
                        'Confirm when the note becomes stable and in tune',
                    value: state.hapticEnabled,
                    onChanged: (_) => notifier.toggleHapticFeedback(),
                  ),
                  _SettingSwitch(
                    title: 'Stage Mode',
                    subtitle: 'Show a simplified full-screen tuning display',
                    value: state.stageModeEnabled,
                    onChanged: (_) => notifier.toggleStageModeEnabled(),
                  ),
                  const SizedBox(height: MonoPulseSpacing.lg),
                  Divider(color: MonoPulseColors.borderSubtle),
                  const SizedBox(height: MonoPulseSpacing.md),
                  Text(
                    'Microphone privacy',
                    style: MonoPulseTypography.labelMedium.copyWith(
                      color: MonoPulseColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MonoPulseSpacing.sm),
                  Text(
                    'Pitch detection runs locally. Raw microphone audio is never stored or sent to FlowGroove servers.',
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: MonoPulseColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MonoPulseTypography.labelMedium.copyWith(
        color: MonoPulseColors.textSecondary,
      ),
    );
  }
}

class _PresetSummary extends StatelessWidget {
  final String instrument;
  final String tuning;

  const _PresetSummary({required this.instrument, required this.tuning});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Text(
        '$instrument · $tuning',
        style: MonoPulseTypography.bodyMedium.copyWith(
          color: MonoPulseColors.textHighEmphasis,
        ),
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MonoPulseSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SectionLabel(label)),
              Text(
                valueLabel,
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: MonoPulseColors.accentOrange,
            inactiveColor: MonoPulseColors.borderSubtle,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: MonoPulseTypography.labelMedium.copyWith(
          color: MonoPulseColors.textSecondary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: MonoPulseTypography.bodySmall.copyWith(
          color: MonoPulseColors.textTertiary,
        ),
      ),
      value: value,
      activeTrackColor: MonoPulseColors.accentOrange,
      onChanged: onChanged,
    );
  }
}
