/// Fine adjustment buttons for BPM control
///
/// Provides precise BPM adjustments with +/- buttons.
/// Features:
/// - ±1 BPM (fine tuning)
/// - ±5 BPM (medium adjustment)
/// - ±10 BPM (coarse adjustment)
/// - Icon-based design
/// - Haptic feedback
/// - Compact layout
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Fine adjustment buttons widget
class FineAdjustmentButtons extends ConsumerWidget {
  const FineAdjustmentButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(metronomeProvider.notifier);

    return Wrap(
      spacing: MonoPulseSpacing.sm,
      runSpacing: MonoPulseSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        _AdjustButton(
          icon: Icons.remove,
          delta: -10,
          tooltip: '-10 BPM',
          notifier: notifier,
        ),
        _AdjustButton(
          icon: Icons.remove,
          delta: -5,
          tooltip: '-5 BPM',
          notifier: notifier,
        ),
        _AdjustButton(
          icon: Icons.remove,
          delta: -1,
          tooltip: '-1 BPM',
          notifier: notifier,
        ),
        _AdjustButton(
          icon: Icons.add,
          delta: 1,
          tooltip: '+1 BPM',
          notifier: notifier,
        ),
        _AdjustButton(
          icon: Icons.add,
          delta: 5,
          tooltip: '+5 BPM',
          notifier: notifier,
        ),
        _AdjustButton(
          icon: Icons.add,
          delta: 10,
          tooltip: '+10 BPM',
          notifier: notifier,
        ),
      ],
    );
  }
}

/// Individual adjustment button
class _AdjustButton extends StatelessWidget {

  const _AdjustButton({
    required this.icon,
    required this.delta,
    required this.tooltip,
    required this.notifier,
  });
  final IconData icon;
  final int delta;
  final String tooltip;
  final MetronomeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final isNegative = delta < 0;
    final color = isNegative
        ? MonoPulseColors.textSecondary
        : MonoPulseColors.accentOrange;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isNegative
            ? MonoPulseColors.surfaceRaised
            : MonoPulseColors.accentOrangeSubtle,
        borderRadius: BorderRadius.circular(MonoPulseRadius.small),
        child: SizedBox(
          width: 48,
          height: 48,
          child: InkWell(
            borderRadius: BorderRadius.circular(MonoPulseRadius.small),
            onTap: () => _onTap(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: MonoPulseIcons.sizeMedium),
                Text(
                  delta.abs().toString(),
                  style: MonoPulseTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    notifier.adjustTempoFine(delta);

    // Haptic feedback
    HapticFeedback.lightImpact();
  }
}
