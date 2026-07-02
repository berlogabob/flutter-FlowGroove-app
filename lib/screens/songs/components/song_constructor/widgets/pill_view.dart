import 'package:flutter/material.dart';

import '../../../../../models/section.dart';
import '../../../../../theme/mono_pulse_theme.dart';
import '../core/theme/app_colors.dart';

/// Pill visualization widget for collapsed state.
/// Shows colored blocks proportional to section durations.
class PillView extends StatelessWidget {

  const PillView({required this.sections, super.key});
  final List<Section> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return Center(
        child: Text(
          'No structure yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    return Container(
      height: AppDimensions.pillHeight,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.pillBorderRadius),
      ),
      padding: const EdgeInsets.all(MonoPulseSpacing.xs),
      child: Row(
        children: [
          for (var i = 0; i < sections.length; i++)
            Expanded(
              flex: sections[i].duration,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: sections[i].color,
                  // First/last chips follow the outer pill's curve
                  // (concentric — Flutter clamps the radius to fit, keeping
                  // it offset from the outer edge by the padding). Inner
                  // edges stay square-ish.
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(
                      i == 0 ? AppDimensions.pillBorderRadius : 4,
                    ),
                    right: Radius.circular(
                      i == sections.length - 1
                          ? AppDimensions.pillBorderRadius
                          : 4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
