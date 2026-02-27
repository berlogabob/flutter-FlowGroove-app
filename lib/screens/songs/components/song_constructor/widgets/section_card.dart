import 'package:flutter/material.dart';
import '../../../../../models/section.dart';
import '../core/theme/app_colors.dart';
import '../../../../../theme/mono_pulse_theme.dart';

/// Card widget for displaying a section in expanded state.
class SectionCard extends StatelessWidget {
  final Section section;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final int? dragIndex;
  final bool enableDrag;

  const SectionCard({
    super.key,
    required this.section,
    this.onTap,
    this.onDelete,
    this.dragIndex,
    this.enableDrag = false,
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
        trailing: _buildTrailing(context),
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
    return Text(
      section.name,
      style:
          Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
          const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'Duration: ${section.duration} ${section.duration == 1 ? 'phrase' : 'phrases'}',
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ) ??
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (section.notes.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            section.notes,
            style:
                Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic) ??
                const TextStyle(fontStyle: FontStyle.italic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (enableDrag && dragIndex != null)
          ReorderableDragStartListener(
            index: dragIndex!,
            child: const Icon(
              Icons.drag_handle,
              color: MonoPulseColors.textSecondary,
              size: 20,
            ),
          ),
        if (!enableDrag) ...[
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            color: Theme.of(context).colorScheme.error,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.drag_handle,
            color: MonoPulseColors.textSecondary,
            size: 20,
          ),
        ],
      ],
    );
  }
}
