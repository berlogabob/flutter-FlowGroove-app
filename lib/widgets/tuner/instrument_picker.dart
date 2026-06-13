import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instrument.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Instrument Picker - Bottom sheet for selecting instrument and tuning.
///
/// Shows a list of available instruments with their icon and origin.
/// Tapping an instrument expands to show its available tunings.
class InstrumentPicker extends ConsumerWidget {
  const InstrumentPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: MonoPulseColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MonoPulseRadius.xlarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: MonoPulseSpacing.sm),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MonoPulseColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MonoPulseSpacing.xl,
              MonoPulseSpacing.lg,
              MonoPulseSpacing.xl,
              MonoPulseSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Instrument',
                  style: MonoPulseTypography.headlineSmall.copyWith(
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
          ),

          const Divider(height: 1, color: MonoPulseColors.borderSubtle),

          // Instrument list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                vertical: MonoPulseSpacing.sm,
              ),
              itemCount: state.instruments.length,
              itemBuilder: (context, index) {
                final instrument = state.instruments[index];
                final isSelected =
                    state.selectedInstrument?.id == instrument.id;

                return _InstrumentTile(
                  instrument: instrument,
                  tunings: isSelected
                      ? state.availableTunings
                      : instrument.tunings,
                  isSelected: isSelected,
                  isExpanded: isSelected,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    notifier.selectInstrument(instrument);
                  },
                  onTuningSelected: (tuning) {
                    HapticFeedback.lightImpact();
                    notifier.selectTuning(tuning);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentTile extends StatelessWidget {
  final Instrument instrument;
  final List<Tuning> tunings;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final void Function(Tuning) onTuningSelected;

  const _InstrumentTile({
    required this.instrument,
    required this.tunings,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    required this.onTuningSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Instrument row
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? MonoPulseColors.accentOrangeSubtle
                  : MonoPulseColors.surfaceRaised,
              borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
            ),
            child: Icon(
              _iconDataFromString(icon: instrument.icon),
              color: isSelected
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textSecondary,
              size: 22,
            ),
          ),
          title: Text(
            instrument.name,
            style: MonoPulseTypography.bodyLarge.copyWith(
              color: isSelected
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textHighEmphasis,
              fontWeight: isSelected
                  ? MonoPulseTypography.semibold
                  : MonoPulseTypography.regular,
            ),
          ),
          subtitle: Text(
            instrument.subtitle,
            style: MonoPulseTypography.bodySmall.copyWith(
              color: MonoPulseColors.textTertiary,
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: MonoPulseColors.textTertiary,
            size: 20,
          ),
          onTap: onTap,
        ),

        // Expanded tunings
        if (isExpanded)
          AnimatedSize(
            duration: MonoPulseAnimation.durationMedium,
            curve: MonoPulseAnimation.curveCustom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: tunings
                  .map(
                    (tuning) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MonoPulseSpacing.xxxl,
                        vertical: MonoPulseSpacing.xs,
                      ),
                      child: _TuningChip(
                        tuning: tuning,
                        onTap: () => onTuningSelected(tuning),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  IconData _iconDataFromString({required String icon}) {
    switch (icon.toLowerCase()) {
      case 'music_note':
        return Icons.music_note_outlined;
      case 'star':
        return Icons.star_outline;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'wb_sunny':
        return Icons.wb_sunny_outlined;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'mic':
        return Icons.mic_none;
      case 'graphic_eq':
        return Icons.graphic_eq;
      default:
        return Icons.piano_outlined;
    }
  }
}

class _TuningChip extends StatelessWidget {
  final Tuning tuning;
  final VoidCallback onTap;

  const _TuningChip({required this.tuning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.lg,
          vertical: MonoPulseSpacing.md,
        ),
        decoration: BoxDecoration(
          color: MonoPulseColors.surfaceRaised,
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tune_outlined,
              color: MonoPulseColors.textTertiary,
              size: 18,
            ),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: Text(
                tuning.name,
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
              ),
            ),
            Text(
              tuning.notes.join(' · '),
              style: MonoPulseTypography.labelSmall.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
