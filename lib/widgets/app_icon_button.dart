import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Accessible icon button with built-in semantics and tooltip.
///
/// Automatically wraps IconButton with:
/// - Semantics label for screen readers
/// - Tooltip on hover/long-press
/// - Ensures minimum tap target (48×48px per Material Design)
///
/// Usage:
/// ```dart
/// AppIconButton(
///   icon: Icons.edit,
///   label: 'Edit song',
///   onPressed: _handleEdit,
/// )
/// ```
class AppIconButton extends StatelessWidget {
  /// Icon to display
  final IconData icon;

  /// Semantic label for screen readers; also used as tooltip text
  final String label;

  /// Called when button is pressed
  final VoidCallback? onPressed;

  /// Icon size (defaults to MonoPulseIcons.sizeMedium = 20)
  final double size;

  /// Icon color (defaults to textSecondary)
  final Color? color;

  /// Padding around the icon (for tap target sizing)
  final EdgeInsetsGeometry? padding;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.size = 20, // MonoPulseIcons.sizeMedium
    this.padding = const EdgeInsets.all(14), // 48×48 min tap target (20px + 14*2)
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon),
          iconSize: size,
          color: color ?? MonoPulseColors.textSecondary,
          padding: padding,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
