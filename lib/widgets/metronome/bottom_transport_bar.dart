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
class BottomTransportBar extends ConsumerWidget {
  const BottomTransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metronome = ref.watch(metronomeProvider.notifier);
    final state = ref.watch(metronomeProvider);
    final isPlaying = state.isPlaying;
    final hasSetlist = state.loadedSetlist != null;

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.xxxl,
        vertical: MonoPulseSpacing.lg,
      ),
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
            ),
            const SizedBox(width: MonoPulseSpacing.xl),
          ],

          // Play/Pause button (center)
          _PlayButton(
            isPlaying: isPlaying,
            onTap: () {
              HapticFeedback.mediumImpact();
              metronome.toggle();
            },
          ),

          // Next button (only if setlist loaded)
          if (hasSetlist) ...[
            const SizedBox(width: MonoPulseSpacing.xl),
            _NavigationButton(
              icon: Icons.fast_forward,
              onTap: () {
                HapticFeedback.lightImpact();
                metronome.nextSetlistSong();
              },
              isEnabled:
                  state.currentSetlistIndex <
                  state.loadedSetlist!.songIds.length - 1,
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

  const _PlayButton({required this.isPlaying, required this.onTap});

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
          // Minimum 48px touch zone (actual size 80x64)
          width: 80,
          height: 64,
          decoration: BoxDecoration(
            color: MonoPulseColors.accentOrange,
            borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause : Icons.play_arrow,
            color: MonoPulseColors.black,
            size: 48,
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

  const _NavigationButton({
    required this.icon,
    required this.onTap,
    this.isEnabled = true,
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
          // Minimum 48px touch zone (actual size 56x56)
          width: 56,
          height: 56,
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
            size: 32,
          ),
        ),
      ),
    );
  }
}
