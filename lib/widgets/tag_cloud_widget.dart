import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';

class TagCloudWidget extends StatelessWidget {
  final Map<String, int> tagCounts;
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;
  final int maxTags;

  const TagCloudWidget({
    super.key,
    required this.tagCounts,
    this.selectedTag,
    required this.onTagSelected,
    this.maxTags = 10,
  });

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
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: selectedTag == null,
                onSelected: (_) => onTagSelected(null),
                selectedColor: MonoPulseColors.accentOrange.withOpacity(0.3),
                checkmarkColor: MonoPulseColors.accentOrange,
              ),
            );
          }

          final entry = tags[index - 1];
          final tag = entry.key;
          final count = entry.value;
          final intensity = count / maxCount;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('$tag ($count)'),
              selected: selectedTag == tag,
              onSelected: (_) => onTagSelected(selectedTag == tag ? null : tag),
              selectedColor: MonoPulseColors.accentOrange.withOpacity(0.3),
              checkmarkColor: MonoPulseColors.accentOrange,
              backgroundColor: _getTagColor(intensity),
            ),
          );
        },
      ),
    );
  }

  Color _getTagColor(double intensity) {
    // Light orange based on intensity
    final opacity = 0.1 + (intensity * 0.2);
    return MonoPulseColors.accentOrange.withOpacity(opacity.clamp(0.1, 0.3));
  }
}
