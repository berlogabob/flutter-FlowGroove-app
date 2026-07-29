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

    return SizedBox(
      height: 40,
      // Right-edge fade signals the row scrolls horizontally (F-021: the last
      // chip used to clip flush against the screen edge with no affordance).
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.9, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: MonoPulseSpacing.xl),
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

            // Neutral unselected chips (no orange "brown" tint); orange is
            // reserved for the selected state only. F-012.
            return Padding(
              padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
              child: AppFilterChip(
                label: '$tag ($count)',
                selected: selectedTag == tag,
                onSelected: (_) =>
                    onTagSelected(selectedTag == tag ? null : tag),
              ),
            );
          },
        ),
      ),
    );
  }
}
