import 'package:flutter/material.dart';
import 'unified_item_model.dart';

class UnifiedItemTrailingActions<T extends UnifiedItemModel>
    extends StatelessWidget {
  final T item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final List<UnifiedItemAction> customActions;
  final bool showCompact;

  const UnifiedItemTrailingActions({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
    this.customActions = const [],
    this.showCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];

    // Add type-specific actions
    if (item is SongItemAdapter &&
        (item as SongItemAdapter).spotifyUrl != null) {
      actions.add(
        IconButton(
          icon: const Icon(
            Icons.play_circle_fill,
            color: Colors.green,
            size: 28,
          ),
          onPressed: () async {
            final song = item as SongItemAdapter;
            if (song.spotifyUrl != null) {
              final uri = Uri.parse(song.spotifyUrl!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          tooltip: 'Play on Spotify',
        ),
      );
    }

    // Add custom actions
    actions.addAll(customActions.map((action) => action.build()));

    // Add standard edit/delete actions
    if (onEdit != null || item.onEdit != null) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
          onPressed: onEdit ?? item.onEdit,
          tooltip: 'Edit',
        ),
      );
    }

    if (onDelete != null || item.onDelete != null) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
          onPressed: onDelete ?? item.onDelete,
          tooltip: 'Delete',
        ),
      );
    }

    // Add export PDF for setlists
    if (item is SetlistItemAdapter) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, size: 20, color: Colors.blue),
          onPressed: (item as SetlistItemAdapter).onExportPdf,
          tooltip: 'Export PDF',
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}
