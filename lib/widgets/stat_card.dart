import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import '../utils/responsive_breakpoints.dart';
import 'app_card.dart';

/// Statistics card displaying an icon, value, and label.
///
/// Responsive design adapts icon sizes, typography, and spacing
/// based on the current screen breakpoint.
///
/// Features:
/// - Responsive icon and text sizing
/// - Adaptive aspect ratio
/// - Optional tap callback with ripple effect
/// - Consistent theming using MonoPulseColors
///
/// Usage:
/// ```dart
/// // Basic usage
/// StatCard(
///   icon: Icons.music_note,
///   label: 'Songs',
///   value: '42',
///   color: MonoPulseColors.accentOrange,
///   onTap: () => context.goNamed('songs'),
/// )
///
/// // With custom aspect ratio
/// StatCard(
///   icon: Icons.groups,
///   label: 'Bands',
///   value: '3',
///   color: MonoPulseColors.textSecondary,
///   aspectRatio: 4.0,
/// )
/// ```
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
    this.aspectRatio,
    this.onTap,
  });

  /// Icon to display.
  final IconData icon;

  /// Label text.
  final String label;

  /// Value text (the statistic).
  final String value;

  /// Icon color.
  final Color color;

  /// Callback when card is tapped (optional).
  final VoidCallback? onTap;

  /// Custom aspect ratio (optional, uses responsive default if not provided).
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final iconSize = ResponsiveSizes.iconSize(breakpoint);
    final valueFontSize = ResponsiveSizes.valueFontSize(breakpoint);
    final labelFontSize = ResponsiveSizes.labelFontSize(breakpoint);

    // Canonical surface card from the design system (Phase 4).
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.sm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(height: MonoPulseSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: valueFontSize,
              height: 1,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MonoPulseColors.textTertiary,
              fontSize: labelFontSize,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
