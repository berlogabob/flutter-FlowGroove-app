import 'package:material_ui/material_ui.dart';

import '../theme/mono_pulse_theme.dart';

enum SectionHeaderStyle {
  /// titleMedium, text colour: a section inside a screen.
  title,

  /// labelMedium, secondary colour: a quiet group label in forms and sheets.
  label,
}

/// Section title with an optional trailing action ("See all").
///
/// Mirrored by the FigCraft "SectionHeader" component (Code Connect in
/// design/figcraft/build.py).
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    this.style = SectionHeaderStyle.title,
    this.textStyle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: MonoPulseSpacing.sm),
    super.key,
  });

  final String title;
  final SectionHeaderStyle style;

  /// Overrides the style's type, e.g. labelSmall for a denser sheet.
  final TextStyle? textStyle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final base = style == SectionHeaderStyle.title
        ? MonoPulseTypography.titleMedium.copyWith(
            color: context.mp.textPrimary,
          )
        : MonoPulseTypography.labelMedium.copyWith(
            color: context.mp.textSecondary,
          );
    final text = Text(title, style: base.merge(textStyle));
    return Padding(
      padding: padding,
      child: actionLabel == null
          ? text
          : Row(
              children: [
                Expanded(child: text),
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: MonoPulseTypography.labelMedium.copyWith(
                      color: MonoPulseColors.accentOrange,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
