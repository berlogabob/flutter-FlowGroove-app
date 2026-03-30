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

/// Fine adjustment buttons widget
class FineAdjustmentButtons extends ConsumerWidget {
  const FineAdjustmentButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(metronomeProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
  final IconData icon;
  final int delta;
  final String tooltip;
  final dynamic notifier;

  const _AdjustButton({
    required this.icon,
    required this.delta,
    required this.tooltip,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = delta < 0;
    final color = isNegative
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    final currentBpm = notifier.state.bpm;
    final newBpm = (currentBpm + delta).clamp(10, 260);
    notifier.setBpm(newBpm);

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Visual feedback
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('BPM: $currentBpm → $newBpm'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
