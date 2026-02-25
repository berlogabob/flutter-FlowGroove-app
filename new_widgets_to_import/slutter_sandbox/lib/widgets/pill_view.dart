import 'package:flutter/material.dart';
import '../models/section.dart';
import '../core/theme/section_color_manager.dart';
import '../core/theme/app_colors.dart';

/// Pill visualization widget for collapsed state.
/// Shows colored blocks proportional to section durations.
class PillView extends StatelessWidget {
  final List<Section> sections;

  const PillView({
    super.key,
    required this.sections,
  });

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
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.pillBorderRadius),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: sections.map((section) {
          return Expanded(
            flex: section.duration,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: section.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
