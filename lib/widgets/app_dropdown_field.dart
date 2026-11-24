import 'package:material_ui/material_ui.dart';

import '../theme/mono_pulse_theme.dart';

/// Dropdown form field for the white-filled input (design system `input`).
///
/// The selected value, the arrow and the open menu are dark on white in both
/// themes; the menu is white too because `style` also styles the menu items.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.decoration,
    this.hint,
    this.isExpanded = false,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final InputDecoration? decoration;
  final Widget? hint;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context)
          .copyWith(disabledColor: MonoPulseColors.textDisabled),
      child: DropdownButtonFormField<T>(
        initialValue: initialValue,
        items: items,
        onChanged: onChanged,
        decoration: decoration ?? const InputDecoration(),
        hint: hint,
        isExpanded: isExpanded,
        style: MonoPulseTypography.bodyLarge.copyWith(
          color: MonoPulseColors.charcoal,
        ),
        dropdownColor: MonoPulseColors.white,
        iconEnabledColor: MonoPulseColors.charcoal,
        iconDisabledColor: MonoPulseColors.textDisabled,
      ),
    );
  }
}
