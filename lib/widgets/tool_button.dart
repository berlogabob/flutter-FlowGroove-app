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
  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Callback when button is pressed (null = disabled).
  final VoidCallback? onTap;

  /// Compact mode for tablet/desktop layouts (optional).
  final bool isCompact;

  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final isEnabled = onTap != null;
    final iconSize = ResponsiveSizes.iconSize(breakpoint);
    final fontSize = ResponsiveSizes.buttonFontSize(breakpoint);
    final minSize = ResponsiveSizes.minCardHeight(breakpoint);

    return Material(
      color: isEnabled
          ? MonoPulseColors.surface
          : MonoPulseColors.surfaceOverlay,
      borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? MonoPulseSpacing.md : MonoPulseSpacing.lg,
            vertical: isCompact ? MonoPulseSpacing.xs : MonoPulseSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isEnabled
                ? MonoPulseColors.surface
                : MonoPulseColors.surfaceOverlay,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            border: Border.all(color: MonoPulseColors.borderSubtle),
          ),
          constraints: BoxConstraints(
            minWidth: minSize,
            minHeight: minSize,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isEnabled
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textTertiary,
                size: iconSize,
              ),
              SizedBox(height: isCompact ? 2 : MonoPulseSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isEnabled
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.textTertiary,
                  fontSize: fontSize,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isEnabled) ...[
                SizedBox(height: isCompact ? 2 : MonoPulseSpacing.xs),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: MonoPulseSpacing.sm,
                    vertical: 2,
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
            ],
          ),
        ),
      ),
    );
  }
}
