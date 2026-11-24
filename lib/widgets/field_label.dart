import 'package:material_ui/material_ui.dart';

import '../theme/mono_pulse_theme.dart';

/// Label drawn above an input (design system `input` node): medium body text
/// with an optional red asterisk. Shared by `CustomTextField` and by every
/// non-text input (dropdowns, pickers) so labels never float onto the field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final style = MonoPulseTypography.bodyMedium.copyWith(
      color: context.mp.textPrimary,
      fontWeight: FontWeight.w500,
    );
    return Text.rich(
      TextSpan(
        text: label,
        style: style,
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: style.copyWith(color: MonoPulseColors.error),
            ),
        ],
      ),
    );
  }
}

/// Stacks a `FieldLabel` above `child` with the design-system gap.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final bool required;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, required: required),
        const SizedBox(height: MonoPulseSpacing.md),
        child,
      ],
    );
  }
}
