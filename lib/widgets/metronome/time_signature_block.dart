import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Time Signature Block widget - Mono Pulse design
///
/// Horizontal panel with two rows:
/// - Top row: Accent beats with +/- buttons
/// - Bottom row: Regular beats with +/- buttons
///
/// Circles represent beats:
/// - Inactive: #222222 fill + #333333 stroke
/// - Accent: #FF5E00 fill
/// - Current beat: #FF5E00 + pulse animation (scale 1.08)
class TimeSignatureBlock extends ConsumerWidget {
  const TimeSignatureBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);
    final isPlaying = state.isPlaying;
    final currentBeat = state.currentBeat;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      decoration: BoxDecoration(
        color: MonoPulseColors.blackSurface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
        border: Border.all(color: MonoPulseColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      child: Column(
        children: [
          // Top row - Accent beats
          _BeatRow(
            label: 'Accent',
            count: state.accentBeats,
            maxCount: state.regularBeats,
            isAccent: true,
            currentBeat: isPlaying ? currentBeat : -1,
            onIncrement: () {
              HapticFeedback.lightImpact();
              metronome.setAccentBeats(state.accentBeats + 1);
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              metronome.setAccentBeats(state.accentBeats - 1);
            },
          ),
          const SizedBox(height: MonoPulseSpacing.md),
          // Bottom row - Regular beats
          _BeatRow(
            label: 'Beats',
            count: state.regularBeats,
            maxCount: 12,
            isAccent: false,
            currentBeat: isPlaying ? currentBeat : -1,
            onIncrement: () {
              HapticFeedback.lightImpact();
              metronome.setRegularBeats(state.regularBeats + 1);
            },
            onDecrement: () {
              HapticFeedback.lightImpact();
              metronome.setRegularBeats(state.regularBeats - 1);
            },
          ),
        ],
      ),
    );
  }
}

class _BeatRow extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final bool isAccent;
  final int currentBeat;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _BeatRow({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.isAccent,
    required this.currentBeat,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Label
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: MonoPulseTypography.labelMedium.copyWith(
              color: MonoPulseColors.textTertiary,
            ),
          ),
        ),

        // Minus button
        _BeatButton(icon: Icons.remove, onTap: count > 1 ? onDecrement : null),

        const SizedBox(width: MonoPulseSpacing.md),

        // Beat circles
        Expanded(
          child: Row(
            children: List.generate(
              count,
              (index) => Padding(
                padding: EdgeInsets.only(
                  right: index < count - 1 ? MonoPulseSpacing.sm : 0,
                ),
                child: _BeatCircle(
                  index: index,
                  isAccent: isAccent,
                  isActive: currentBeat == index,
                  showBadge: count > 6,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: MonoPulseSpacing.sm),

        // Plus button
        _BeatButton(
          icon: Icons.add,
          onTap: count < maxCount ? onIncrement : null,
        ),
      ],
    );
  }
}

class _BeatCircle extends StatelessWidget {
  final int index;
  final bool isAccent;
  final bool isActive;
  final bool showBadge;

  const _BeatCircle({
    required this.index,
    required this.isAccent,
    required this.isActive,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    const circleSize = 16.0;
    const badgeSize = 14.0;

    // Badge for numbers > 6
    Widget? badge;
    if (showBadge && index >= 6) {
      badge = Positioned(
        right: -2,
        top: -2,
        child: Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            color: MonoPulseColors.accentOrange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: MonoPulseColors.black,
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedScale(
      scale: isActive ? 1.08 : 1.0,
      duration: MonoPulseAnimation.durationShort,
      curve: MonoPulseAnimation.curveDefault,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAccent
                  ? MonoPulseColors.accentOrange
                  : (isActive
                        ? MonoPulseColors.accentOrange
                        : MonoPulseColors.borderSubtle),
              border: Border.all(
                color: isAccent || isActive
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.borderDefault,
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: MonoPulseColors.accentOrange.withValues(
                          alpha: 0.4,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          ),
          if (badge != null) badge,
        ],
      ),
    );
  }
}

class _BeatButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _BeatButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Minimum 48px touch zone
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isEnabled
              ? MonoPulseColors.blackElevated
              : MonoPulseColors.blackElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
          border: Border.all(
            color: isEnabled
                ? MonoPulseColors.borderSubtle
                : MonoPulseColors.borderSubtle.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isEnabled
              ? MonoPulseColors.textSecondary
              : MonoPulseColors.textDisabled,
        ),
      ),
    );
  }
}
