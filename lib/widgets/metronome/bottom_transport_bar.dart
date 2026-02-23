import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data/metronome_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Bottom Transport Bar widget - Mono Pulse design
///
/// Horizontal row at bottom (64-80px height):
/// - Center: Large oval Play button (radius 32px, background #FF5E00)
///   - White icon 48px (▶ when stopped, ‖ when playing)
///   - Tap to toggle play/stop
/// - If setlist loaded:
///   - Left: Previous button (circle #111111, icon ◀◀ #A0A0A5 → orange on tap)
///   - Right: Next button (circle #111111, icon ▶▶ #A0A0A5 → orange on tap)
/// - Icons large (48px touch zone) for stage use
/// - Fixed height: 64px minimum, always visible at bottom
class BottomTransportBar extends ConsumerWidget {
  const BottomTransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);
    final isPlaying = state.isPlaying;
    final hasSetlist = state.loadedSetlist != null;

    // Adaptive sizing for small screens
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final barHeight = isSmallScreen ? 64.0 : 80.0;
    final playButtonWidth = isSmallScreen ? 64.0 : 80.0;
    final playButtonHeight = isSmallScreen ? 56.0 : 64.0;
    final navButtonSize = isSmallScreen ? 48.0 : 56.0;
    final navIconSize = isSmallScreen ? 24.0 : 32.0;
    final horizontalMargin = isSmallScreen
        ? MonoPulseSpacing.xxl
        : MonoPulseSpacing.xxxl;
    final buttonSpacing = isSmallScreen
        ? MonoPulseSpacing.lg
        : MonoPulseSpacing.xl;

    return Container(
      height: barHeight,
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      // NO vertical margin - prevents button from being clipped
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button (only if setlist loaded)
          if (hasSetlist) ...[
            _NavigationButton(
              icon: Icons.fast_rewind,
              onTap: () {
                HapticFeedback.lightImpact();
                metronome.previousSetlistSong();
              },
              isEnabled: state.currentSetlistIndex > 0,
              buttonSize: navButtonSize,
              iconSize: navIconSize,
            ),
            SizedBox(width: buttonSpacing),
          ],

          // Play/Pause button (center)
          _PlayButton(
            isPlaying: isPlaying,
            onTap: () {
              HapticFeedback.mediumImpact();
              metronome.toggle();
            },
            buttonWidth: playButtonWidth,
            buttonHeight: playButtonHeight,
          ),

          // Next button (only if setlist loaded)
          if (hasSetlist) ...[
            SizedBox(width: buttonSpacing),
            _NavigationButton(
              icon: Icons.fast_forward,
              onTap: () {
                HapticFeedback.lightImpact();
                metronome.nextSetlistSong();
              },
              isEnabled:
                  state.currentSetlistIndex <
                  state.loadedSetlist!.songIds.length - 1,
              buttonSize: navButtonSize,
              iconSize: navIconSize,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double buttonWidth;
  final double buttonHeight;

  const _PlayButton({
    required this.isPlaying,
    required this.onTap,
    this.buttonWidth = 80.0,
    this.buttonHeight = 64.0,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

    if (widget.isPlaying) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Adaptive icon size based on button size
    final iconSize = widget.buttonWidth * 0.6;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
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
          // Minimum 48px touch zone (adaptive size)
          width: widget.buttonWidth,
          height: widget.buttonHeight,
          decoration: BoxDecoration(
            color: MonoPulseColors.accentOrange,
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause : Icons.play_arrow,
            color: MonoPulseColors.black,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;
  final double buttonSize;
  final double iconSize;

  const _NavigationButton({
    required this.icon,
    required this.onTap,
    this.isEnabled = true,
    this.buttonSize = 56.0,
    this.iconSize = 32.0,
  });

  @override
  State<_NavigationButton> createState() => _NavigationButtonState();
}

class _NavigationButtonState extends State<_NavigationButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.isEnabled;
    final isPressed = _isPressed && isEnabled;

    return GestureDetector(
      onTapDown: (_) {
        if (isEnabled) {
          setState(() => _isPressed = true);
          HapticFeedback.vibrate();
        }
      },
      onTapUp: (_) {
        if (isEnabled) {
          setState(() => _isPressed = false);
          HapticFeedback.vibrate();
          widget.onTap();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: isPressed ? 0.95 : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: Container(
          // Minimum 48px touch zone (adaptive size)
          width: widget.buttonSize,
          height: widget.buttonSize,
          decoration: BoxDecoration(
            color: isPressed
                ? MonoPulseColors.accentOrange.withValues(alpha: 0.2)
                : MonoPulseColors.blackElevated,
            shape: BoxShape.circle,
            border: Border.all(
              color: isPressed
                  ? MonoPulseColors.accentOrange
                  : (isEnabled
                        ? MonoPulseColors.borderSubtle
                        : MonoPulseColors.borderSubtle.withValues(alpha: 0.3)),
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            color: isPressed
                ? MonoPulseColors.accentOrange
                : (isEnabled
                      ? MonoPulseColors.textSecondary
                      : MonoPulseColors.textDisabled),
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}
