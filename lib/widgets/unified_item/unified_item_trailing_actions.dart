import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'unified_item_model.dart';
import 'adapters/song_item_adapter.dart';
import 'adapters/setlist_item_adapter.dart';

/// Trailing actions widget for unified items
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
    final colors = Theme.of(context).colorScheme;
    final List<Widget> actions = [];

    // Add Spotify play button for songs
    if (item is SongItemAdapter) {
      final song = item as SongItemAdapter;
      if (song.spotifyUrl != null) {
        actions.add(
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill,
              color: Colors.green,
              size: 28,
            ),
            onPressed: () async {
              final uri = Uri.parse(song.spotifyUrl!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: 'Play on Spotify',
          ),
        );
      }
    }

    // Add custom actions
    actions.addAll(customActions.map((action) => action.build()));

    // Add edit action
    if (onEdit != null) {
      actions.add(
        IconButton(
          icon: Icon(Icons.edit, size: 20, color: colors.onSurfaceVariant),
          onPressed: onEdit,
          tooltip: 'Edit',
        ),
      );
    }

    // Add delete action
    if (onDelete != null) {
      actions.add(
        IconButton(
          icon: Icon(Icons.delete, size: 20, color: colors.error),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
      );
    }

    // Add PDF export for setlists
    if (item is SetlistItemAdapter) {
      // PDF export will be added as custom action by the screen
    }

    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}
