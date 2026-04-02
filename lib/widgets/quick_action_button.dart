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
  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Callback when button is pressed.
  final VoidCallback onTap;

  /// Compact mode for tablet/desktop layouts (optional).
  final bool isCompact;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final iconSize = ResponsiveSizes.iconSize(breakpoint);
    final fontSize = ResponsiveSizes.buttonFontSize(breakpoint);
    final minSize = ResponsiveSizes.minCardHeight(breakpoint);

    return Material(
      color: MonoPulseColors.surface,
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
            color: MonoPulseColors.surface,
            border: Border.all(color: MonoPulseColors.borderDefault),
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
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
                color: MonoPulseColors.accentOrange,
                size: iconSize,
              ),
              const Spacer(),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
