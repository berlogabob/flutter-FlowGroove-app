import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mono_pulse_theme.dart';
import 'tool_scaffold.dart';

/// Transport bar for audio tools (Metronome, Tuner, etc.).
///
/// Features:
/// - Play/Pause button (primary action)
/// - Optional navigation buttons (Previous/Next)
/// - Optional settings button
/// - Consistent styling across all tools
/// - Haptic feedback on tap
///
/// Usage:
/// ```dart
/// ToolTransportBar(
///   isPlaying: true,
///   onPlayPause: () => togglePlay(),
///   onPrevious: () => previousPreset(),
///   onNext: () => nextPreset(),
/// )
/// ```
class ToolTransportBar extends StatelessWidget {
  /// Whether currently playing.
  final bool isPlaying;

  /// Callback for play/pause button.
  final VoidCallback onPlayPause;

  /// Callback for previous button (optional).
  final VoidCallback? onPrevious;

  /// Callback for next button (optional).
  final VoidCallback? onNext;

  /// Callback for settings button (optional).
  final VoidCallback? onSettings;

  /// Whether to show navigation buttons.
  final bool showNavigation;

  /// Whether to show settings button.
  final bool showSettings;

  const ToolTransportBar({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onSettings,
    this.showNavigation = false,
    this.showSettings = false,
  });

  @override
  Widget build(BuildContext context) {
    final touchSize = ToolTouchTarget.large(context);

    return Container(
      height: 80,
      margin: EdgeInsets.symmetric(
        horizontal: ToolSpacing.xxxl(context),
        vertical: ToolSpacing.lg(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          if (showNavigation && onPrevious != null)
            _TransportButton(
              icon: Icons.skip_previous,
              onTap: onPrevious!,
              size: touchSize,
            ),

          // Play/Pause button (primary)
          _PlayPauseButton(
            isPlaying: isPlaying,
            onTap: onPlayPause,
            size: touchSize * 1.2,
          ),

          // Next button
          if (showNavigation && onNext != null)
            _TransportButton(
              icon: Icons.skip_next,
              onTap: onNext!,
              size: touchSize,
            ),

          // Settings button
          if (showSettings && onSettings != null)
            _TransportButton(
              icon: Icons.settings,
              onTap: onSettings!,
              size: touchSize,
            ),
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MonoPulseColors.accentOrange,
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _TransportButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MonoPulseColors.surfaceRaised,
          border: Border.all(color: MonoPulseColors.borderSubtle, width: 1),
        ),
        child: Icon(
          icon,
          color: MonoPulseColors.textSecondary,
          size: size * 0.4,
        ),
      ),
    );
  }
}
