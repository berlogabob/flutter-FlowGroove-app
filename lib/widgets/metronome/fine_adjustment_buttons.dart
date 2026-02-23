import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Fine Adjustment Buttons widget - Mono Pulse design
///
/// Horizontal row of buttons for precise tempo adjustment:
/// - +1/-1, +5/-5, +10/-10 groups
/// - Each button: radius 20px, background #111111, stroke #222222
/// - Text/icon: #A0A0A5 (tap #FF5E00 fill)
/// - Minimum 48px touch zones for stage use
class FineAdjustmentButtons extends ConsumerWidget {
  const FineAdjustmentButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // +1 / -1 group
          _AdjustmentGroup(
            delta: 1,
            onAdjust: (delta) {
              HapticFeedback.lightImpact();
              metronome.adjustTempoFine(delta);
            },
          ),
          const SizedBox(width: MonoPulseSpacing.lg),
          // +5 / -5 group
          _AdjustmentGroup(
            delta: 5,
            onAdjust: (delta) {
              HapticFeedback.lightImpact();
              metronome.adjustTempoFine(delta);
            },
          ),
          const SizedBox(width: MonoPulseSpacing.lg),
          // +10 / -10 group
          _AdjustmentGroup(
            delta: 10,
            onAdjust: (delta) {
              HapticFeedback.lightImpact();
              metronome.adjustTempoFine(delta);
            },
          ),
        ],
      ),
    );
  }
}

class _AdjustmentGroup extends StatelessWidget {
  final int delta;
  final Function(int) onAdjust;

  const _AdjustmentGroup({required this.delta, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: MonoPulseColors.borderSubtle, width: 1),
          right: BorderSide(color: MonoPulseColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FineButton(label: '-$delta', onTap: () => onAdjust(-delta)),
          const SizedBox(width: MonoPulseSpacing.sm),
          _FineButton(label: '+$delta', onTap: () => onAdjust(delta)),
        ],
      ),
    );
  }
}

class _FineButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _FineButton({required this.label, required this.onTap});

  @override
  State<_FineButton> createState() => _FineButtonState();
}

class _FineButtonState extends State<_FineButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
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
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: Container(
          // Minimum 48px touch zone
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            color: _isPressed
                ? MonoPulseColors.accentOrange.withValues(alpha: 0.2)
                : MonoPulseColors.blackElevated,
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
            border: Border.all(
              color: _isPressed
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: MonoPulseTypography.labelLarge.copyWith(
                color: _isPressed
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
