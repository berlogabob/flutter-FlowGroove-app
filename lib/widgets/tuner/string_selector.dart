import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// String Selector - Horizontal row of string pills for manual mode.
///
/// Shows one pill per string of the selected instrument.
/// Each pill displays the string label and target note (e.g., "6: E2").
/// Tapping a pill sets it as the target for manual detection.
class StringSelector extends ConsumerWidget {
  const StringSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);

    final instrument = state.selectedInstrument;
    final tuning = state.selectedTuning;

    if (instrument == null || tuning == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(instrument.stringCount, (index) {
          final label = index < instrument.stringLabels.length
              ? instrument.stringLabels[index]
              : '${index + 1}';
          final note = index < tuning.notes.length ? tuning.notes[index] : '?';
          final isSelected = state.manualTargetStringIndex == index;

          return Padding(
            padding: EdgeInsets.only(
              right: index < instrument.stringCount - 1
                  ? MonoPulseSpacing.sm
                  : 0,
            ),
            child: _StringPill(
              label: label,
              note: note,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.setManualTargetStringIndex(index);
              },
            ),
          );
        }),
      ),
    );
  }
}

class _StringPill extends StatelessWidget {
  final String label;
  final String note;
  final bool isSelected;
  final VoidCallback onTap;

  const _StringPill({
    required this.label,
    required this.note,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MonoPulseAnimation.durationMedium,
        curve: MonoPulseAnimation.curveCustom,
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? MonoPulseColors.accentOrange
              : MonoPulseColors.surfaceRaised,
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
          border: Border.all(
            color: isSelected
                ? MonoPulseColors.accentOrange
                : MonoPulseColors.borderDefault,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MonoPulseTypography.labelSmall.copyWith(
                color: isSelected
                    ? MonoPulseColors.black
                    : MonoPulseColors.textTertiary,
                fontWeight: MonoPulseTypography.semibold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: MonoPulseTypography.bodyMedium.copyWith(
                color: isSelected
                    ? MonoPulseColors.white
                    : MonoPulseColors.textSecondary,
                fontWeight: MonoPulseTypography.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
