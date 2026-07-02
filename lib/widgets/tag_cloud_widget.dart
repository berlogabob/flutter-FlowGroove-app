import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';
import 'app_filter_chip.dart';

class TagCloudWidget extends StatelessWidget {

  const TagCloudWidget({
    required this.tagCounts,
    required this.onTagSelected,
    super.key,
    this.maxTags = 10,
    this.selectedTag,
  });
  final Map<String, int> tagCounts;
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;
  final int maxTags;

  @override
  Widget build(BuildContext context) {
    if (tagCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final tags = tagCounts.entries.take(maxTags).toList();
    final maxCount = tags.isNotEmpty ? tags.first.value : 1;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length + 1, // +1 for "All" chip
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" chip
            return Padding(
              padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
              child: AppFilterChip(
                label: 'All',
                selected: selectedTag == null,
                onSelected: (_) => onTagSelected(null),
              ),
            );
          }

          final entry = tags[index - 1];
          final tag = entry.key;
          final count = entry.value;
          final intensity = count / maxCount;

          return Padding(
            padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
            child: AppFilterChip(
              label: '$tag ($count)',
              selected: selectedTag == tag,
              onSelected: (_) => onTagSelected(selectedTag == tag ? null : tag),
              unselectedBackgroundColor: _getTagColor(intensity),
            ),
          );
        },
      ),
    );
  }

  Color _getTagColor(double intensity) {
    // Light orange based on intensity
    final opacity = 0.1 + (intensity * 0.2);
    return MonoPulseColors.accentOrange.withValues(
      alpha: opacity.clamp(0.1, 0.3),
    );
  }
}
