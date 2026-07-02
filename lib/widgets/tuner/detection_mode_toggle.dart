import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instrument.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Detection Mode Toggle - Auto/Manual pill toggle.
///
/// Placed above the central dial in Listen mode.
/// - Auto: Detects whatever note is being played
/// - Manual: User selects a specific string to listen for
class DetectionModeToggle extends ConsumerWidget {
  const DetectionModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(MonoPulseSpacing.xs),
      decoration: BoxDecoration(
        color: MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auto mode pill
          _ModeOption(
            label: 'Auto',
            icon: Icons.auto_awesome_outlined,
            isActive: state.detectionMode == DetectionMode.auto,
            onTap: () {
              HapticFeedback.selectionClick();
              notifier.setDetectionMode(DetectionMode.auto);
            },
          ),
          const SizedBox(width: MonoPulseSpacing.xs),
          // Manual mode pill
          _ModeOption(
            label: 'Manual',
            icon: Icons.tune_outlined,
            isActive: state.detectionMode == DetectionMode.manual,
            onTap: () {
              HapticFeedback.selectionClick();
              notifier.setDetectionMode(DetectionMode.manual);
            },
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {

  const _ModeOption({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MonoPulseAnimation.durationMedium,
        curve: MonoPulseAnimation.curveCustom,
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.lg,
          vertical: MonoPulseSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? MonoPulseColors.accentOrange10
              : Colors.transparent,
          borderRadius: BorderRadius.circular(MonoPulseRadius.medium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.textTertiary,
            ),
            const SizedBox(width: MonoPulseSpacing.xs),
            Text(
              label,
              style: MonoPulseTypography.labelMedium.copyWith(
                color: isActive
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
                fontWeight:
                    isActive ? MonoPulseTypography.semibold : MonoPulseTypography.regular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
