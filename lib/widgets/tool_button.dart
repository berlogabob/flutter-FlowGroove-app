import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';

/// Tool button for dashboard and other screens.
///
/// Responsive design adapts icon sizes, typography, and spacing
/// based on the current screen breakpoint. Supports disabled state
/// with "Soon" badge for upcoming features.
///
/// Features:
/// - Responsive icon and text sizing
/// - Vertical layout (icon above text) for better space utilization
/// - Disabled state with "Soon" badge
/// - Ripple effect on tap (when enabled)
/// - Consistent theming using MonoPulseColors
/// - Minimum touch target size for accessibility
///
/// Usage:
/// ```dart
/// // Enabled tool button
/// ToolButton(
///   icon: Icons.tune,
///   label: 'Tuner',
///   onTap: () => context.goNamed('tuner'),
/// )
///
/// // Disabled tool button (shows "Soon" badge)
/// ToolButton(
///   icon: Icons.speed,
///   label: 'Metronome',
/// )
///
/// // Compact mode for desktop
/// ToolButton(
///   icon: Icons.library_music,
///   label: 'Bank',
///   onTap: () => context.goNamed('songs'),
///   isCompact: true,
/// )
/// ```
class ToolButton extends StatelessWidget {
  const ToolButton({
    required this.icon, required this.label, super.key,
    this.isCompact = false,
    this.onTap,
  });

  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Callback when button is pressed (null = disabled).
  final VoidCallback? onTap;

  /// Compact mode for tablet/desktop layouts (optional).
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final isEnabled = onTap != null;
    final iconSize = ResponsiveSizes.iconSize(breakpoint);
    final fontSize = ResponsiveSizes.buttonFontSize(breakpoint);

    final accent = isEnabled
        ? MonoPulseColors.accentOrange
        : MonoPulseColors.textTertiary;

    // Mono Pulse tile: a uniform horizontal row (icon left, label right) that
    // fills its grid cell, matching Quick Actions for consistent density (A9).
    return Material(
      color: isEnabled
          ? MonoPulseColors.surface
          : MonoPulseColors.surfaceOverlay,
      borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.md,
            vertical: MonoPulseSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isEnabled
                ? MonoPulseColors.surface
                : MonoPulseColors.surfaceOverlay,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            border: Border.all(color: MonoPulseColors.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: iconSize),
              const SizedBox(width: MonoPulseSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MonoPulseSpacing.sm,
                    vertical: MonoPulseSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: MonoPulseColors.borderStrong,
                    borderRadius: BorderRadius.circular(MonoPulseRadius.small),
                  ),
                  child: Text(
                    'Soon',
                    style: MonoPulseTypography.labelSmall.copyWith(
                      color: MonoPulseColors.textPrimary,
                      fontSize: fontSize - 2,
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
