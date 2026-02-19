import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// A customizable text field widget with consistent styling.
///
/// This widget provides a reusable text input field with support for
/// various input types, validation, and optional prefix/suffix icons.
class CustomTextField extends StatelessWidget {
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

  /// Input formatters for custom input validation.
  final List<TextInputFormatter>? inputFormatters;

  /// Callback when the field gains focus.
  final VoidCallback? onFocus;

  /// Callback when the field loses focus.
  final VoidCallback? onBlur;

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
    this.inputFormatters,
    this.onFocus,
    this.onBlur,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: AppColors.color4,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              children: required
                  ? [
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red),
                      ),
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          onTap: onFocus,
          onEditingComplete: onBlur,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
