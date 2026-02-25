import 'package:flutter/material.dart';
import '../models/section.dart';
import '../core/theme/section_color_manager.dart';
import '../core/theme/app_colors.dart';

/// Card widget for displaying a section in expanded state.
class SectionCard extends StatelessWidget {
  final Section section;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SectionCard({
    super.key,
    required this.section,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = section.color;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildColorIndicator(color),
        title: _buildTitle(context),
        subtitle: _buildSubtitle(context),
        trailing: _buildDragHandle(context),
      ),
    );
  }

  Widget _buildColorIndicator(Color color) {
    return Container(
      width: AppDimensions.cardLeadingWidth,
      height: AppDimensions.cardLeadingHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius / 2),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            section.name,
            style: AppTextStyles.sectionTitle(context),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
          color: Theme.of(context).colorScheme.error,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'Duration: ${section.duration} ${section.duration == 1 ? 'phrase' : 'phrases'}',
          style: AppTextStyles.sectionSubtitle(context),
        ),
        if (section.notes.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            section.notes,
            style: AppTextStyles.sectionNotes(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    return Icon(
      Icons.drag_handle,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
      size: 20,
    );
  }
}
