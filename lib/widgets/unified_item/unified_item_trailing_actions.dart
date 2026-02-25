import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'unified_item_model.dart';
import 'adapters/song_item_adapter.dart';

/// Trailing actions widget for unified items
class UnifiedItemTrailingActions<T extends UnifiedItemModel>
    extends StatelessWidget {
  final T item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final List<UnifiedItemAction> customActions;
  final bool showCompact;
  final List<UnifiedItemAction> additionalActions;

  const UnifiedItemTrailingActions({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
    this.customActions = const [],
    this.showCompact = false,
    this.additionalActions = const [],
  });

  @override
  Widget build(BuildContext context) {
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
    actions.addAll(customActions.map((action) => action.build(context)));

    // Add additional actions (e.g., Add to Band)
    actions.addAll(additionalActions.map((action) => action.build(context)));

    // NOTE: Edit and Delete buttons removed - use tap-to-edit and swipe-to-delete instead
    // This follows the unified interaction pattern

    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}
