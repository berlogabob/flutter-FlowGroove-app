import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Settings Bottom Sheet for Tuner
///
/// Minimal settings panel with:
/// - A4 calibration slider (432-445 Hz)
/// - Haptic feedback toggle
/// - Stage mode toggle
/// - Current instrument/tuning display
/// - About text
class TunerSettingsSheet extends ConsumerWidget {
  const TunerSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(MonoPulseRadius.large)),
      ),
      padding: const EdgeInsets.fromLTRB(
        MonoPulseSpacing.xl,
        MonoPulseSpacing.lg,
        MonoPulseSpacing.xl,
        MonoPulseSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tuner Settings',
                style: MonoPulseTypography.titleMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 24),
                color: MonoPulseColors.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.xl),

          // Current Instrument Display
          if (state.selectedInstrument != null) ...[
            Text(
              'Current Instrument',
              style: MonoPulseTypography.labelMedium.copyWith(
                color: MonoPulseColors.textSecondary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.sm),
            Container(
              padding: const EdgeInsets.all(MonoPulseSpacing.md),
              decoration: BoxDecoration(
                color: MonoPulseColors.surfaceRaised,
                borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                border: Border.all(color: MonoPulseColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.piano_outlined,
                    color: MonoPulseColors.accentOrange,
                    size: 20,
                  ),
                  const SizedBox(width: MonoPulseSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.selectedInstrument!.name,
                          style: MonoPulseTypography.bodyMedium.copyWith(
                            color: MonoPulseColors.textHighEmphasis,
                            fontWeight: MonoPulseTypography.medium,
                          ),
                        ),
                        Text(
                          state.selectedTuning?.name ?? '',
                          style: MonoPulseTypography.bodySmall.copyWith(
                            color: MonoPulseColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.xl),
          ],

          // A4 Calibration
          Text(
            'A4 Reference Frequency',
            style: MonoPulseTypography.labelMedium.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: MonoPulseColors.accentOrange,
                    inactiveTrackColor: MonoPulseColors.borderSubtle,
                    thumbColor: MonoPulseColors.accentOrange,
                    overlayColor: MonoPulseColors.accentOrange.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: state.referenceA4,
                    min: 432,
                    max: 445,
                    divisions: 13,
                    label: '${state.referenceA4.round()} Hz',
                    onChanged: notifier.setReferenceA4,
                  ),
                ),
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              SizedBox(
                width: 70,
                child: Text(
                  '${state.referenceA4.round()} Hz',
                  textAlign: TextAlign.right,
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                    fontWeight: MonoPulseTypography.medium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.xl),

          // Haptic Feedback Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Haptic Feedback',
                style: MonoPulseTypography.labelMedium.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
              ),
              Switch(
                value: state.hapticEnabled,
                onChanged: (_) => notifier.toggleHapticFeedback(),
                activeTrackColor: MonoPulseColors.accentOrange,
                activeThumbColor: MonoPulseColors.white,
                trackOutlineColor: WidgetStateProperty.all(MonoPulseColors.borderDefault),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.lg),

          // Stage Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stage Mode',
                    style: MonoPulseTypography.labelMedium.copyWith(
                      color: MonoPulseColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Hide UI after 10s inactivity',
                    style: MonoPulseTypography.bodySmall.copyWith(
                      color: MonoPulseColors.textTertiary,
                    ),
                  ),
                ],
              ),
              Switch(
                value: state.stageModeEnabled,
                onChanged: (_) => notifier.toggleStageModeEnabled(),
                activeTrackColor: MonoPulseColors.accentOrange,
                activeThumbColor: MonoPulseColors.white,
                trackOutlineColor: WidgetStateProperty.all(MonoPulseColors.borderDefault),
              ),
            ],
          ),
          const SizedBox(height: MonoPulseSpacing.xl),

          // About
          Divider(color: MonoPulseColors.borderSubtle),
          const SizedBox(height: MonoPulseSpacing.md),
          Text(
            'About Tuner',
            style: MonoPulseTypography.labelMedium.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.sm),
          Text(
            'Offline-first professional tuner\n'
            'YIN pitch detection algorithm\n'
            '${state.instruments.length} instruments · ${state.instruments.fold<int>(0, (sum, i) => sum + i.tunings.length)}+ tunings\n'
            'No ads • No subscriptions • Always free',
            style: MonoPulseTypography.bodySmall.copyWith(
              color: MonoPulseColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
