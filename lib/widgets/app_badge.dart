import 'package:material_ui/material_ui.dart';

import '../theme/mono_pulse_theme.dart';

/// Pill label with an optional leading icon: band facts, status, offline.
///
/// Mirrored by the FigCraft "Badge" component (Code Connect in
/// design/figcraft/build.py).
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.icon,
    this.trailingIcon,
    this.color = MonoPulseColors.accentOrange,
    this.outlined = false,
    super.key,
  }) : solidLabelColor = null;

  /// Solid pill: [color] fills the badge and [labelColor] is the label
  /// (white or charcoal by contrast, e.g. section letters).
  const AppBadge.solid({
    required this.label,
    required this.color,
    required Color labelColor,
    super.key,
  }) : icon = null,
       trailingIcon = null,
       outlined = false,
       solidLabelColor = labelColor;

  final String label;
  final IconData? icon;

  /// e.g. a chevron when the badge is tappable (wrap it in an InkWell).
  final IconData? trailingIcon;

  /// Tint, icon and (unless [outlined]) label colour.
  final Color color;

  /// Adds a [color] border and shows the label in the text colour.
  final bool outlined;

  /// Non-null for [AppBadge.solid].
  final Color? solidLabelColor;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        solidLabelColor ?? (outlined ? context.mp.textPrimary : color);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.md,
        vertical: MonoPulseSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: solidLabelColor != null ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MonoPulseRadius.huge),
        border: outlined ? Border.all(color: color) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MonoPulseIcons.sizeSmall, color: color),
            const SizedBox(width: MonoPulseSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MonoPulseTypography.bodySmall.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: MonoPulseSpacing.xs),
            Icon(trailingIcon, size: MonoPulseIcons.sizeSmall, color: color),
          ],
        ],
      ),
    );
  }
}
