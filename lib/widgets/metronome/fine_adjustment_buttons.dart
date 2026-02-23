import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Fine Adjustment Buttons widget - Mono Pulse design (Sprint Fix)
///
/// Horizontal row of buttons for precise tempo adjustment:
/// - Order left to right: -10, -5, -1, +1, +5, +10
/// - No numbers/signs — +/- icons only
///   - 1 icon for ±1
///   - 2 icons for ±5
///   - 3 icons for ±10
/// - Circle radius 20px, background #111111, stroke #222222
/// - Icon: #A0A0A5 (tap #FF5E00 fill)
/// - Minimum 48px touch zones for stage use
/// - Compact layout: single horizontal row, reduced height from 80px to 48px
/// - Smaller icons (16px instead of 20px) on small screens
class FineAdjustmentButtons extends ConsumerWidget {
  const FineAdjustmentButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxxl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Check if we need horizontal scroll for narrow screens
          // Each button needs ~56px + spacing, total ~400px for 6 buttons
          final needsScroll = constraints.maxWidth < 400;

          // Adaptive spacing for small screens
          final buttonSpacing = isSmallScreen
              ? MonoPulseSpacing.xs
              : MonoPulseSpacing.sm;

          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TempoButton(
                    arrowCount: 3,
                    direction: -1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      metronome.adjustTempoFine(-10);
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: buttonSpacing),
                  _TempoButton(
                    arrowCount: 2,
                    direction: -1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      metronome.adjustTempoFine(-5);
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: buttonSpacing),
                  _TempoButton(
                    arrowCount: 1,
                    direction: -1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      metronome.adjustTempoFine(-1);
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: buttonSpacing),
                  _TempoButton(
                    arrowCount: 1,
                    direction: 1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      metronome.adjustTempoFine(1);
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: buttonSpacing),
                  _TempoButton(
                    arrowCount: 2,
                    direction: 1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      metronome.adjustTempoFine(5);
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: buttonSpacing),
                  _TempoButton(
                    arrowCount: 3,
                    direction: 1,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      metronome.adjustTempoFine(10);
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                ],
              ),
            );
          }

          // Normal layout without scroll
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TempoButton(
                arrowCount: 3,
                direction: -1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  metronome.adjustTempoFine(-10);
                },
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(width: buttonSpacing),
              _TempoButton(
                arrowCount: 2,
                direction: -1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  metronome.adjustTempoFine(-5);
                },
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(width: buttonSpacing),
              _TempoButton(
                arrowCount: 1,
                direction: -1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  metronome.adjustTempoFine(-1);
                },
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(width: buttonSpacing),
              _TempoButton(
                arrowCount: 1,
                direction: 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  metronome.adjustTempoFine(1);
                },
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(width: buttonSpacing),
              _TempoButton(
                arrowCount: 2,
                direction: 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  metronome.adjustTempoFine(5);
                },
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(width: buttonSpacing),
              _TempoButton(
                arrowCount: 3,
                direction: 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  metronome.adjustTempoFine(10);
                },
                isSmallScreen: isSmallScreen,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TempoButton extends StatefulWidget {
  final int arrowCount;
  final int direction; // -1 for down, 1 for up
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _TempoButton({
    required this.arrowCount,
    required this.direction,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  State<_TempoButton> createState() => _TempoButtonState();
}

class _TempoButtonState extends State<_TempoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Compact button sizing: reduced from 48px to 40px on small screens
    final buttonSize = widget.isSmallScreen ? 40.0 : 48.0;
    final arrowSize = widget.isSmallScreen ? 6.0 : 8.0;
    final iconSpacing = widget.isSmallScreen ? 1.0 : 2.0;

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
          // Compact button size for small screens
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: _isPressed
                ? MonoPulseColors.accentOrange.withValues(alpha: 0.2)
                : MonoPulseColors.blackElevated, // #111111
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge), // 20px
            border: Border.all(
              color: _isPressed
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.borderSubtle, // #222222
              width: 1,
            ),
          ),
          child: Center(
            child: _ArrowIcon(
              count: widget.arrowCount,
              direction: widget.direction,
              color: _isPressed
                  ? MonoPulseColors
                        .accentOrange // #FF5E00 on tap
                  : MonoPulseColors.textSecondary, // #A0A0A5 default
              arrowSize: arrowSize,
              spacing: iconSpacing,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowIcon extends StatelessWidget {
  final int count;
  final int direction; // -1 for decrease, 1 for increase
  final Color color;
  final double arrowSize;
  final double spacing;

  const _ArrowIcon({
    required this.count,
    required this.direction,
    required this.color,
    this.arrowSize = 8.0,
    this.spacing = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    // Stack arrows vertically based on count - LEFT/RIGHT arrows
    final totalHeight = count * arrowSize + (count - 1) * spacing;

    return SizedBox(
      width: 16,
      height: totalHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index < count - 1 ? spacing : 0),
            child: Icon(
              direction == 1
                  ? Icons
                        .arrow_forward // ▶ right arrow for increase
                  : Icons.arrow_back, // ◀ left arrow for decrease
              size: arrowSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
