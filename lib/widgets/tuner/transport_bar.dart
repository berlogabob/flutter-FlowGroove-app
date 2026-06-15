import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tuner_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import 'settings_sheet.dart';

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
          if (state.mode == TunerMode.generate)
            _VolumeControl(
              volume: state.volume,
              onVolumeChanged: notifier.setVolume,
            )
          else
            _InputLevelIndicator(levelDb: state.inputLevelDb),
          const SizedBox(width: MonoPulseSpacing.xxl),

          // Play/Stop or Start/Stop button (center)
          _MainActionButton(
            mode: state.mode,
            isActive: state.mode == TunerMode.generate
                ? state.isPlaying
                : state.isListening,
            isStarting: state.isStarting,
            onTap: state.isStarting
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    if (state.mode == TunerMode.generate) {
                      notifier.togglePlaying();
                    } else {
                      notifier.toggleListening();
                    }
                  },
          ),

          const SizedBox(width: MonoPulseSpacing.xxl),

          _CalibrationButton(
            referenceHz: state.referenceA4,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => const TunerSettingsSheet(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final TunerMode mode;
  final bool isActive;
  final bool isStarting;
  final VoidCallback? onTap;

  const _MainActionButton({
    required this.mode,
    required this.isActive,
    required this.isStarting,
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
            if (isStarting)
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: MonoPulseColors.white,
                ),
              )
            else
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
    final volumeLabel = widget.volume == 0
        ? 'Mute'
        : widget.volume < 1.0
            ? 'Volume down (50%)'
            : 'Volume up (100%)';

    return Semantics(
      button: true,
      enabled: true,
      label: volumeLabel,
      onTap: _cycleVolume,
      child: Tooltip(
        message: 'Cycle volume: Mute → 50% → 100%',
        child: GestureDetector(
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

class _CalibrationButton extends StatelessWidget {
  final double referenceHz;
  final VoidCallback onTap;

  const _CalibrationButton({required this.referenceHz, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: 'Calibration settings (A4 ${referenceHz.round()} Hz)',
      onTap: onTap,
      child: Tooltip(
        message: 'Adjust tuner calibration frequency',
        child: GestureDetector(
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
            const Icon(
              Icons.tune,
              color: MonoPulseColors.accentOrange,
              size: 22,
            ),
            Positioned(
              bottom: 4,
              child: Text(
                'A4 ${referenceHz.round()}',
                style: MonoPulseTypography.labelSmall.copyWith(
                  color: MonoPulseColors.accentOrange,
                  fontSize: 7,
                  fontWeight: MonoPulseTypography.medium,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _InputLevelIndicator extends StatelessWidget {
  final double levelDb;

  const _InputLevelIndicator({required this.levelDb});

  @override
  Widget build(BuildContext context) {
    final normalized = ((levelDb + 70) / 50).clamp(0.0, 1.0);
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: MonoPulseColors.borderSubtle, width: 1.5),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: normalized,
          child: Container(
            width: 12,
            decoration: BoxDecoration(
              color: MonoPulseColors.accentOrange,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
