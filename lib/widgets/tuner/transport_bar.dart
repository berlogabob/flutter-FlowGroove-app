import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/music_mode.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';

/// Bottom Transport Bar widget for Tuner screen
///
/// Horizontal row at bottom (64-80px height):
/// - Center: Large oval Play/Stop button (radius 32px vertical, background #FF5E00)
///   - White icon 48px (▶ / ■)
/// - Left: Volume icon with 3-state cycle (0% → 50% → 100%)
/// - Right: Music Mode cycle button (cycles through scales: Chromatic, Ionian, Dorian, etc.)
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
            onVolumeChanged: notifier.setVolume,
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

          // Music Mode cycle button (right)
          _ModeCycleButton(
            modeIndex: state.musicModeIndex,
            onTap: () {
              // Cycle to next mode
              notifier.cycleMusicMode();
              HapticFeedback.mediumImpact();
              
              // Show NEW mode name after cycling
              final nextIndex = (state.musicModeIndex + 1) % allMusicModes.length;
              final newMode = allMusicModes[nextIndex];
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🎵 ${newMode.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  duration: const Duration(milliseconds: 800),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.orange.withValues(alpha: 0.8),
                ),
              );
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
  final void Function(double) onVolumeChanged;

  const _VolumeControl({required this.volume, required this.onVolumeChanged});

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  /// Cycle through 3 volume states: 0% → 50% → 100% → 0%
  void _cycleVolume() {
    double newVolume;
    if (widget.volume == 0) {
      newVolume = 0.5;
    } else if (widget.volume < 1.0) {
      newVolume = 1.0;
    } else {
      newVolume = 0;
    }
    widget.onVolumeChanged(newVolume);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _cycleVolume,
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
              color: widget.volume == 0
                  ? MonoPulseColors.textTertiary
                  : MonoPulseColors.textSecondary,
              size: 28,
            ),
            // Volume level indicator bar
            if (widget.volume > 0)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: MonoPulseColors.accentOrange,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            // Mute indicator X overlay
            if (widget.volume == 0)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MonoPulseColors.textTertiary.withValues(alpha: 0.3),
                    width: 2,
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
    } else if (widget.volume < 1.0) {
      return Icons.volume_down_outlined;
    } else {
      return Icons.volume_up_outlined;
    }
  }
}

/// Music Mode Cycle Button - Right side of transport bar
/// Cycles through musical scales (Chromatic, Ionian, Dorian, etc.)
class _ModeCycleButton extends StatelessWidget {
  final int modeIndex;
  final VoidCallback onTap;

  const _ModeCycleButton({
    required this.modeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentMode = allMusicModes[modeIndex];

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
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Mode icon
            Icon(
              currentMode.icon,
              color: MonoPulseColors.accentOrange,
              size: 26,
            ),
            // Mode short name below icon
            Positioned(
              bottom: 4,
              child: Text(
                currentMode.shortName,
                style: MonoPulseTypography.labelSmall.copyWith(
                  color: MonoPulseColors.accentOrange,
                  fontSize: 8,
                  fontWeight: MonoPulseTypography.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
