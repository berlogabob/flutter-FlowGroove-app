import 'package:flutter/material.dart';

import '../models/setlist_break_type.dart';
import '../theme/mono_pulse_theme.dart';

/// A full-width divider bar for a setlist break/section (guest set, break,
/// encore, backup, or a custom-named section). Mirrors the labeled section
/// bars in a real printed setlist — it splits the list visually. Optional
/// [leading]/[trailing] let the editor slot in a drag handle / delete button.
class SetlistBreakRow extends StatelessWidget {
  const SetlistBreakRow({
    required this.breakType,
    required this.label,
    super.key,
    this.leading,
    this.trailing,
  });

  /// A [SetlistBreakType] id (e.g. `guest_set`).
  final String? breakType;

  /// Custom label if set; otherwise the type's default label is used.
  final String? label;

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final type = SetlistBreakType.byId(breakType);
    final text = SetlistBreakType.labelFor(breakType, label);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MonoPulseSpacing.md,
          vertical: MonoPulseSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: MonoPulseColors.accentOrange10,
          borderRadius: BorderRadius.circular(MonoPulseRadius.small),
          border: Border.all(color: MonoPulseColors.accentOrange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Icon(type.icon, size: 18, color: MonoPulseColors.accentOrange),
            const SizedBox(width: MonoPulseSpacing.md),
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: MonoPulseColors.accentOrange,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
