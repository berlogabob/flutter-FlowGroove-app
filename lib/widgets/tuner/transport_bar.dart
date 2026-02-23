import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Bottom Transport Bar widget for Tuner screen
///
/// Horizontal row at bottom (64-80px height):
/// - Center: Large oval Play/Stop button (radius 32px vertical, background #FF5E00)
///   - White icon 48px (▶ / ■)
/// - Left: Volume icon with slider
/// - Right: Settings icon (placeholder)
///
/// INTERACTIVE (Stage 2):
/// - Generate Mode: Play/Stop button controls tone generation
/// - Listen Mode: Start/Stop button controls microphone listening
class TransportBar extends ConsumerWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final notifier = ref.read(tunerProvider.notifier);

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.xxxl,
        vertical: MonoPulseSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Volume icon with slider (left)
          _VolumeControl(
            volume: state.volume,
            onVolumeChanged: (vol) => notifier.setVolume(vol),
          ),
          const SizedBox(width: MonoPulseSpacing.xxl),

          // Play/Stop or Start/Stop button (center)
          _MainActionButton(
            mode: state.mode,
            isActive: state.mode == TunerMode.generate
                ? state.isPlaying
                : state.isListening,
            onTap: () {
              HapticFeedback.mediumImpact();
              if (state.mode == TunerMode.generate) {
                notifier.togglePlaying();
              } else {
                notifier.toggleListening();
              }
            },
          ),

          const SizedBox(width: MonoPulseSpacing.xxl),

          // Settings icon (right, placeholder)
          _IconButton(
            icon: Icons.tune_outlined,
            onTap: () {
              HapticFeedback.lightImpact();
              // Placeholder for settings
            },
          ),
        ],
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final TunerMode mode;
  final bool isActive;
  final VoidCallback onTap;

  const _MainActionButton({
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine icon and label based on mode and state
    IconData icon;
    String? label;

    if (mode == TunerMode.generate) {
      // Generate Tone mode: Play/Stop
      icon = isActive ? Icons.stop : Icons.play_arrow;
    } else {
      // Listen & Tune mode: Start/Stop listening
      icon = isActive ? Icons.stop : Icons.mic;
      if (!isActive) {
        label = 'Listen';
      }
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: MonoPulseAnimation.curveCustom,
        // Oval shape: 80px wide, 64px tall
        width: isActive ? 72 : 80,
        height: 64,
        decoration: BoxDecoration(
          color: isActive
              ? MonoPulseColors.accentOrange
              : MonoPulseColors.accentOrange,
          borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: MonoPulseColors.white, size: 44),
            if (label != null)
              Positioned(
                bottom: -18,
                child: Text(
                  label,
                  style: MonoPulseTypography.labelSmall.copyWith(
                    color: MonoPulseColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VolumeControl extends StatefulWidget {
  final double volume;
  final Function(double) onVolumeChanged;

  const _VolumeControl({required this.volume, required this.onVolumeChanged});

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _isSliderVisible = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSliderVisible = !_isSliderVisible;
        });
        HapticFeedback.lightImpact();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: MonoPulseColors.borderSubtle, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              _getVolumeIcon(),
              color: MonoPulseColors.textSecondary,
              size: 28,
            ),
            // Volume level indicator
            if (widget.volume > 0)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: MonoPulseColors.accentOrange,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getVolumeIcon() {
    if (widget.volume == 0) {
      return Icons.volume_off_outlined;
    } else if (widget.volume < 0.5) {
      return Icons.volume_down_outlined;
    } else {
      return Icons.volume_up_outlined;
    }
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: MonoPulseColors.borderSubtle, width: 1.5),
        ),
        child: Icon(icon, color: MonoPulseColors.textSecondary, size: 28),
      ),
    );
  }
}
