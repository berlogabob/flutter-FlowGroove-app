import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';

/// Quick action button for dashboard and other screens.
///
/// Responsive design adapts icon sizes, typography, and spacing
/// based on the current screen breakpoint.
///
/// Features:
/// - Responsive icon and text sizing
/// - Vertical layout (icon above text) for better space utilization
/// - Ripple effect on tap
/// - Consistent theming using MonoPulseColors
/// - Minimum touch target size for accessibility
///
/// Usage:
/// ```dart
/// // Basic usage
/// QuickActionButton(
///   icon: Icons.add,
///   label: 'Song',
///   onTap: () => context.goNamed('add-song'),
/// )
///
/// // Compact mode for desktop
/// QuickActionButton(
///   icon: Icons.group_add,
///   label: 'Band',
///   onTap: () => context.goNamed('create-band'),
///   isCompact: true,
/// )
/// ```
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
    this.isCompact = false,
  });

  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Callback when button is pressed.
  final VoidCallback onTap;

  /// Compact mode for tablet/desktop layouts (optional).
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final iconSize = ResponsiveSizes.iconSize(breakpoint);
    final fontSize = ResponsiveSizes.buttonFontSize(breakpoint);

    // FlowGroove tile: a uniform hardware-panel row (icon left, label right) that
    // fills its grid cell — consistent density, no dead gutters (audit A9).
    return Material(
      color: context.mp.surfaceRaised,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.md,
            vertical: MonoPulseSpacing.md,
          ),
          decoration: BoxDecoration(
            color: context.mp.surfaceRaised,
            border: Border.all(color: context.mp.borderDefault),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: context.mp.borderStrong.withValues(alpha: 0.24),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: MonoPulseColors.accentOrange, size: iconSize),
              const SizedBox(width: MonoPulseSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: MonoPulseTypography.labelLarge.copyWith(
                    // Neutral label; the orange icon carries the accent so the
                    // tile grid isn't wall-to-wall orange (UX audit F-013).
                    color: context.mp.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
