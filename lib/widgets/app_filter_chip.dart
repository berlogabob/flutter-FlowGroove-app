import 'package:material_ui/material_ui.dart';

import '../theme/mono_pulse_theme.dart';

/// A reusable filter chip with clear selected/unselected states.
///
/// Provides consistent styling for filter chips across the app:
/// - Selected: stone surface + dark text, without a checkmark
/// - Unselected: raised surface, outline and primary text (frame `chip`)
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
      // Stone selection stays calm; a shallow shadow makes the state legible.
      selectedColor: MonoPulseColors.stone,
      elevation: selected ? 2 : 0,
      pressElevation: selected ? 2 : 1,
      shadowColor: context.mp.borderStrong.withValues(alpha: 0.14),
      selectedShadowColor: context.mp.borderStrong.withValues(alpha: 0.22),
      labelStyle: MonoPulseTypography.labelMedium.copyWith(
        color: selected ? MonoPulseColors.charcoal : context.mp.textPrimary,
        fontWeight: MonoPulseTypography.semibold,
      ),
      // Unselected: neutral raised surface per chipTheme (readable, not the old
      // near-black `surface` / brown tint). F-012.
      backgroundColor: unselectedBackgroundColor ?? context.mp.surfaceRaised,
      side: BorderSide(
        color: selected ? context.mp.borderStrong : context.mp.borderDefault,
      ),
      showCheckmark: false,
      // Padding and shape
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.md,
        vertical: MonoPulseSpacing.sm,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MonoPulseRadius.button)),
    );
  }
}
