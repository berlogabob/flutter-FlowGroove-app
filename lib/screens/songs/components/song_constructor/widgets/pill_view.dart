import 'package:flutter/material.dart';
import '../../../../../models/section.dart';
import '../core/theme/app_colors.dart';

/// Pill visualization widget for collapsed state.
/// Shows colored blocks proportional to section durations.
class PillView extends StatelessWidget {

  const PillView({required this.sections, super.key, this.height, this.padding});

  final List<Section> sections;

  /// Overall pill height. Defaults to [AppDimensions.pillHeight]; pass a small
  /// value (e.g. on a list card) for a compact strip.
  final double? height;

  /// Inner padding around the colored blocks. Defaults to 4.
  final double? padding;

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
      height: height ?? AppDimensions.pillHeight,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.pillBorderRadius),
      ),
      padding: EdgeInsets.all(padding ?? 4),
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
