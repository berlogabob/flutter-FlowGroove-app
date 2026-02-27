import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../models/time_signature.dart';
import '../../theme/mono_pulse_theme.dart';

/// Time Signature Controls widget - Preset buttons for common time signatures
/// Replaces dropdowns with intuitive preset chips
///
/// Mono Pulse Design (Sprint Fix):
/// - All colors from MonoPulseColors
/// - All typography from MonoPulseTypography
/// - All spacing from MonoPulseSpacing
/// - All radius from MonoPulseRadius
/// - Animations: 120ms, curveCustom
/// - Touch zones: 48x48px minimum
class TimeSignatureControlsWidget extends ConsumerWidget {
  const TimeSignatureControlsWidget({super.key});

  // Common time signature presets
  static final List<TimeSignature> presets = [
    const TimeSignature(numerator: 4, denominator: 4), // Common time
    const TimeSignature(numerator: 3, denominator: 4), // Waltz
    const TimeSignature(numerator: 6, denominator: 8), // Compound duple
    const TimeSignature(numerator: 2, denominator: 4), // March
    const TimeSignature(numerator: 5, denominator: 4), // Odd meter
    const TimeSignature(numerator: 7, denominator: 8), // Odd meter
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Container(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        decoration: BoxDecoration(
          color: MonoPulseColors.surface,
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          border: Border.all(color: MonoPulseColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Time Signature',
                  style: MonoPulseTypography.labelLarge.copyWith(
                    color: MonoPulseColors.textHighEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: MonoPulseSpacing.xs),
                Tooltip(
                  message:
                      'Defines how many beats are in each measure. Top number = beats per measure, Bottom number = note value that gets one beat.',
                  preferBelow: false,
                  decoration: BoxDecoration(
                    color: MonoPulseColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
                  ),
                  textStyle: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.textSecondary,
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    size: 16,
                    color: MonoPulseColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.xs),
            Text(
              'Select a common time signature',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),

            // Preset chips
            Wrap(
              spacing: MonoPulseSpacing.sm,
              runSpacing: MonoPulseSpacing.sm,
              children: presets.map((ts) {
                final isSelected = state.timeSignature == ts;
                return _TimeSignatureChip(
                  label: '${ts.numerator}/${ts.denominator}',
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    metronome.setTimeSignature(ts);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: MonoPulseSpacing.lg),
            const Divider(
              color: MonoPulseColors.borderSubtle,
              height: 1,
              thickness: 1,
            ),
            const SizedBox(height: MonoPulseSpacing.lg),

            // Current selection display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Current: ',
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MonoPulseSpacing.lg,
                    vertical: MonoPulseSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: MonoPulseColors.accentOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
                    border: Border.all(
                      color: MonoPulseColors.accentOrange.withValues(
                        alpha: 0.3,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${state.timeSignature.numerator}/${state.timeSignature.denominator}',
                    style: MonoPulseTypography.labelLarge.copyWith(
                      color: MonoPulseColors.accentOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSignatureChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeSignatureChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TimeSignatureChip> createState() => _TimeSignatureChipState();
}

class _TimeSignatureChipState extends State<_TimeSignatureChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isPressed = _isPressed;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.vibrate();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.vibrate();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: isPressed ? 0.95 : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: MonoPulseSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? MonoPulseColors.accentOrange.withValues(alpha: 0.15)
                : MonoPulseColors.blackElevated,
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
            border: Border.all(
              color: isSelected
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.borderDefault,
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: MonoPulseTypography.labelMedium.copyWith(
              color: isSelected
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
