import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Single floating action button with consistent styling.
///
/// Features:
/// - Standard 56x56px size
/// - Hero tag for smooth transitions
/// - MonoPulse theme colors
///
/// Usage:
/// ```dart
/// SingleFab(
///   icon: Icons.add,
///   onPressed: _createItem,
///   heroTag: 'items_fab',
/// )
/// ```
class SingleFab extends StatelessWidget {
  /// Icon to display.
  final IconData icon;

  /// Callback when button is pressed.
  final VoidCallback onPressed;

  /// Hero tag for animation (optional).
  final String? heroTag;

  /// Tooltip text (optional).
  final String? tooltip;

  const SingleFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.heroTag,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: MonoPulseColors.accentOrange,
      foregroundColor: Colors.white,
      child: Icon(icon),
    );
  }
}

/// Dual floating action buttons stacked vertically.
///
/// Features:
/// - Primary action (larger, bottom)
/// - Secondary action (smaller, top)
/// - Consistent spacing and styling
///
/// Usage:
/// ```dart
/// DualFab(
///   primary: FabAction(
///     icon: Icons.add,
///     label: 'Create',
///     onPressed: _create,
///   ),
///   secondary: FabAction(
///     icon: Icons.person_add,
///     label: 'Join',
///     onPressed: _join,
///   ),
/// )
/// ```
class DualFab extends StatelessWidget {
  /// Primary action (displayed at bottom).
  final FabAction primary;

  /// Secondary action (displayed at top).
  final FabAction secondary;

  const DualFab({super.key, required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Secondary action (smaller, top)
        _buildSmallFab(
          icon: secondary.icon,
          label: secondary.label,
          onPressed: secondary.onPressed,
        ),
        const SizedBox(height: MonoPulseSpacing.md),
        // Primary action (standard size, bottom)
        _buildStandardFab(
          icon: primary.icon,
          label: primary.label,
          onPressed: primary.onPressed,
        ),
      ],
    );
  }

  Widget _buildSmallFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.small(
      heroTag: '${label}_small_fab',
      onPressed: onPressed,
      tooltip: label,
      backgroundColor: MonoPulseColors.surfaceRaised,
      foregroundColor: MonoPulseColors.accentOrange,
      child: Icon(icon),
    );
  }

  Widget _buildStandardFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      heroTag: '${label}_fab',
      onPressed: onPressed,
      tooltip: label,
      backgroundColor: MonoPulseColors.accentOrange,
      foregroundColor: Colors.white,
      child: Icon(icon),
    );
  }
}

/// Action configuration for FAB buttons.
class FabAction {
  /// Icon to display.
  final IconData icon;

  /// Label for tooltip and hero tag.
  final String label;

  /// Callback when button is pressed.
  final VoidCallback onPressed;

  const FabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}
