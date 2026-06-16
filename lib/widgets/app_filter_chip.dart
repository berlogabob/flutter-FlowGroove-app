import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// A reusable filter chip with clear selected/unselected states.
///
/// Provides consistent styling for filter chips across the app:
/// - Selected: filled accent orange + dark text + checkmark icon
/// - Unselected: outlined border + muted text
///
/// Usage:
/// ```dart
/// AppFilterChip(
///   label: 'All',
///   selected: true,
///   onSelected: (selected) {
///     // Handle selection
///   },
/// )
/// ```
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
    this.unselectedBackgroundColor,
  });

  /// The label displayed in the chip
  final String label;

  /// Whether this chip is currently selected
  final bool selected;

  /// Called when the chip is tapped
  final ValueChanged<bool> onSelected;

  /// Custom background color for unselected state (optional)
  final Color? unselectedBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      // Selected state styling
      selectedColor: MonoPulseColors.accentOrange,
      labelStyle: TextStyle(
        color: selected
            ? MonoPulseColors.textPrimary
            : MonoPulseColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      // Unselected state styling (outlined + muted)
      backgroundColor: unselectedBackgroundColor ?? MonoPulseColors.surface,
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : MonoPulseColors.borderDefault,
      ),
      // Show checkmark icon when selected
      showCheckmark: selected,
      checkmarkColor: MonoPulseColors.textPrimary,
      // Padding and shape
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
