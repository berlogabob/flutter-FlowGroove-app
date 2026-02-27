import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Accent Pattern Editor widget - Visual toggle buttons for each beat
/// Replaces text input with intuitive toggle buttons (Accent/Regular)
///
/// Mono Pulse Design (Sprint Fix):
/// - All colors from MonoPulseColors
/// - All typography from MonoPulseTypography
/// - All spacing from MonoPulseSpacing
/// - All radius from MonoPulseRadius
/// - Animations: 120ms, curveCustom
/// - Touch zones: 48x48px minimum
class AccentPatternEditorWidget extends ConsumerWidget {
  const AccentPatternEditorWidget({super.key});

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Accent Pattern',
                      style: MonoPulseTypography.labelLarge.copyWith(
                        color: MonoPulseColors.textHighEmphasis,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: MonoPulseSpacing.xs),
                    Tooltip(
                      message:
                          'Tap to toggle Accent (strong) or Regular (weak) for each beat',
                      preferBelow: false,
                      decoration: BoxDecoration(
                        color: MonoPulseColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(
                          MonoPulseRadius.medium,
                        ),
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
                // Reset button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    metronome.updateAccentPatternFromTimeSignature();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(MonoPulseSpacing.sm),
                    decoration: BoxDecoration(
                      color: MonoPulseColors.blackElevated,
                      borderRadius: BorderRadius.circular(
                        MonoPulseRadius.medium,
                      ),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: MonoPulseColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.xs),
            Text(
              'Tap to toggle Accent (strong) or Regular (weak) for each beat',
              style: MonoPulseTypography.bodySmall.copyWith(
                color: MonoPulseColors.textTertiary,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.lg),

            // Toggle buttons for each beat
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(state.timeSignature.numerator, (index) {
                final isAccent = state.accentPattern[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MonoPulseSpacing.xs,
                  ),
                  child: _AccentToggleButton(
                    beatNumber: index + 1,
                    isAccent: isAccent,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final newPattern = List<bool>.from(state.accentPattern);
                      newPattern[index] = !newPattern[index];
                      metronome.setAccentPattern(newPattern);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentToggleButton extends StatefulWidget {
  final int beatNumber;
  final bool isAccent;
  final VoidCallback onTap;

  const _AccentToggleButton({
    required this.beatNumber,
    required this.isAccent,
    required this.onTap,
  });

  @override
  State<_AccentToggleButton> createState() => _AccentToggleButtonState();
}

class _AccentToggleButtonState extends State<_AccentToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: MonoPulseAnimation.durationShort,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: MonoPulseAnimation.curveCustom,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AccentToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAccent && !oldWidget.isAccent) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Beat number
        Text(
          '${widget.beatNumber}',
          style: MonoPulseTypography.labelSmall.copyWith(
            color: MonoPulseColors.textTertiary,
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.xs),
        // Toggle button
        GestureDetector(
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
            scale: _isPressed
                ? 0.95
                : (_pulseController.isAnimating ? _pulseAnimation.value : 1.0),
            duration: MonoPulseAnimation.durationShort,
            curve: MonoPulseAnimation.curveCustom,
            child: Container(
              // 48x48px touch zone
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isAccent
                    ? MonoPulseColors.accentOrange.withValues(alpha: 0.15)
                    : MonoPulseColors.blackElevated,
                border: Border.all(
                  color: widget.isAccent
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.borderDefault,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(MonoPulseRadius.large),
              ),
              child: Icon(
                widget.isAccent ? Icons.star : Icons.circle_outlined,
                color: widget.isAccent
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textSecondary,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: MonoPulseSpacing.xs),
        // Label
        Text(
          widget.isAccent ? 'Accent' : 'Regular',
          style: MonoPulseTypography.labelSmall.copyWith(
            color: widget.isAccent
                ? MonoPulseColors.accentOrange
                : MonoPulseColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
