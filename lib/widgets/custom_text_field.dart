import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme/mono_pulse_theme.dart';
import 'field_label.dart';

/// A customizable text field widget with consistent styling.
///
/// This widget provides a reusable text input field with support for
/// various input types, validation, and optional prefix/suffix icons.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.readOnly = false,
    this.enabled = true,
    this.inputFormatters,
    this.onFocus,
    this.onBlur,
    this.fieldKey,
    this.focusNode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.initialValue,
    this.maxLength,
    this.minLines,
    this.autovalidateMode,
    this.onTap,
    this.helperText,
    this.errorText,
    this.suffixText,
    this.prefixText,
    this.textAlign = TextAlign.start,
    this.style,
    this.isDense,
    this.contentPadding,
    this.semanticsLabel,
    this.counterText,
  });

  /// Key placed on the inner text field (for tests and focus lookups).
  final Key? fieldKey;

  /// Focus node of the inner text field.
  final FocusNode? focusNode;

  /// Whether the field takes focus when first built.
  final bool autofocus;

  /// How the keyboard capitalises typed text.
  final TextCapitalization textCapitalization;

  /// The keyboard action button.
  final TextInputAction? textInputAction;

  /// Initial text when no [controller] is given.
  final String? initialValue;

  /// Maximum number of characters (counter is hidden).
  final int? maxLength;

  /// Minimum number of visible lines.
  final int? minLines;

  /// When the validator runs on its own.
  final AutovalidateMode? autovalidateMode;

  /// Callback when the field is tapped.
  final VoidCallback? onTap;

  /// Helper text shown under the field.
  final String? helperText;

  /// Error text forced under the field (overrides the validator message).
  final String? errorText;

  /// Text shown after the input.
  final String? suffixText;

  /// Text shown before the input.
  final String? prefixText;

  /// Horizontal alignment of the typed text.
  final TextAlign textAlign;

  /// Overrides the input text style.
  final TextStyle? style;

  /// Announced label when the field has no visible [label] (hint only).
  final String? semanticsLabel;

  /// Replaces the character counter (pass an empty string to hide it).
  final String? counterText;

  /// Compact vertical padding.
  final bool? isDense;

  /// Overrides the inner padding of the field.
  final EdgeInsetsGeometry? contentPadding;

  /// The label displayed above the field.
  final String? label;

  /// Hint text shown when the field is empty.
  final String? hint;

  /// Controller for managing the text input.
  final TextEditingController? controller;

  /// Callback when the text value changes.
  final ValueChanged<String>? onChanged;

  /// Callback when the user submits the input.
  final ValueChanged<String>? onSubmitted;

  /// Validator function for form validation.
  final String? Function(String?)? validator;

  /// Whether the field is required.
  final bool required;

  /// The type of keyboard to use for input.
  final TextInputType keyboardType;

  /// Whether the input should be obscured (for passwords).
  final bool obscureText;

  /// Maximum number of lines (null for single line).
  final int? maxLines;

  /// An optional icon to display before the input.
  final IconData? prefixIcon;

  /// An optional widget to display after the input.
  final Widget? suffix;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether the field accepts input. Disabled fields use a stone surface.
  final bool enabled;

  /// Input formatters for custom input validation.
  final List<TextInputFormatter>? inputFormatters;

  /// Callback when the field gains focus.
  final VoidCallback? onFocus;

  /// Callback when the field loses focus.
  final VoidCallback? onBlur;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          ExcludeSemantics(child: FieldLabel(label!, required: required)),
          const SizedBox(height: MonoPulseSpacing.md),
        ],
        _announced(
          TextFormField(
            key: fieldKey,
            controller: controller,
            initialValue: initialValue,
            focusNode: focusNode,
            autofocus: autofocus,
            textCapitalization: textCapitalization,
            textInputAction: textInputAction,
            maxLength: maxLength,
            minLines: minLines,
            autovalidateMode: autovalidateMode,
            textAlign: textAlign,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLines: maxLines,
            readOnly: readOnly,
            enabled: enabled,
            inputFormatters: inputFormatters,
            onTap: (onFocus == null && onTap == null)
                ? null
                : () {
                    onFocus?.call();
                    onTap?.call();
                  },
            onEditingComplete: onBlur,
            // The field is white in both themes (design system input): dark text.
            style:
                style ??
                MonoPulseTypography.bodyLarge.copyWith(
                  color: MonoPulseColors.charcoal,
                ),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled
                  ? MonoPulseColors.white
                  : MonoPulseColors.stone,
              hintText: hint,
            counterText: counterText,
              isDense: isDense,
              contentPadding: contentPadding,
              helperText: helperText,
              errorText: errorText,
              suffixText: suffixText,
              prefixText: prefixText,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }

  /// Keeps the label announced with the field now that it is drawn outside it.
  Widget _announced(Widget field) {
    final text = label == null
        ? semanticsLabel
        : (required ? '$label *' : label);
    if (text == null) return field;
    return Semantics(label: text, child: field);
  }
}
