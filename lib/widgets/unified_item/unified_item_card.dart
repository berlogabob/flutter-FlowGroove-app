import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'unified_item_model.dart';

class UnifiedItemCard<T extends UnifiedItemModel> extends StatelessWidget {
  final T item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool showCompact;
  final List<UnifiedItemAction> customActions;

  const UnifiedItemCard({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.showCompact = false,
    this.customActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: _buildLeadingIcon(context),
        title: Text(
          item.title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: showCompact ? FontWeight.w500 : FontWeight.bold,
            fontSize: showCompact ? 14 : 16,
          ),
        ),
        subtitle: _buildSubtitle(context),
        trailing: UnifiedItemTrailingActions(
          item: item,
          onEdit: onEdit ?? item.onEdit,
          onDelete: onDelete ?? item.onDelete,
          customActions: [...customActions, ...item.customActions],
          showCompact: showCompact,
        ),
        onTap: onTap ?? item.onTap,
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    // Type-specific icon based on item type
    if (item is SongItemAdapter) {
      return const CircleAvatar(
        backgroundColor: Color(0xFF1A1A1A),
        child: Icon(Icons.music_note, color: Colors.orange),
      );
    } else if (item is BandItemAdapter) {
      return const CircleAvatar(
        backgroundColor: Color(0xFF1A1A1A),
        child: Icon(Icons.groups, color: Colors.orange),
      );
    } else if (item is SetlistItemAdapter) {
      return const CircleAvatar(
        backgroundColor: Color(0xFF1A1A1A),
        child: Icon(Icons.playlist_play, color: Colors.orange),
      );
    }
    return const CircleAvatar(
      backgroundColor: Color(0xFF1A1A1A),
      child: Icon(Icons.info, color: Colors.orange),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    if (showCompact) {
      return _buildCompactSubtitle();
    }

    final List<Widget> subtitleWidgets = [];

    // Add type-specific subtitle content
    if (item is SongItemAdapter) {
      final song = item as SongItemAdapter;
      if (song.subtitle?.isNotEmpty == true) {
        subtitleWidgets.add(
          Text(
            song.subtitle!,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }

      // Add BPM and key badges
      if (song.ourBPM != null || song.ourKey != null) {
        final List<Widget> badges = [];
        if (song.ourBPM != null) {
          badges.add(
            UnifiedItemBadge(text: '${song.ourBPM} BPM', color: Colors.orange),
          );
        }
        if (song.ourKey != null) {
          badges.add(
            UnifiedItemBadge(text: song.ourKey!, color: Colors.orange),
          );
        }
        subtitleWidgets.add(Row(children: badges));
      }
    } else if (item is BandItemAdapter) {
      final band = item as BandItemAdapter;
      if (band.subtitle?.isNotEmpty == true) {
        subtitleWidgets.add(
          Text(
            band.subtitle!,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }
      subtitleWidgets.add(
        Text(
          '${band.membersCount} ${band.membersCount == 1 ? 'member' : 'members'}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    } else if (item is SetlistItemAdapter) {
      final setlist = item as SetlistItemAdapter;
      subtitleWidgets.add(
        Text(
          '${setlist.songIdsLength} ${setlist.songIdsLength == 1 ? 'song' : 'songs'}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );

      if (setlist.bandName?.isNotEmpty == true) {
        subtitleWidgets.add(
          Text(
            setlist.bandName!,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }

      if (setlist.eventDate != null) {
        subtitleWidgets.add(
          Text(
            _formatDate(setlist.eventDate),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subtitleWidgets,
    );
  }

  Widget _buildCompactSubtitle() {
    final List<Widget> compactSubtitles = [];

    if (item is SongItemAdapter) {
      final song = item as SongItemAdapter;
      if (song.ourKey != null) {
        compactSubtitles.add(
          Text(
            song.ourKey!,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      }
      if (song.ourBPM != null) {
        compactSubtitles.add(const SizedBox(width: 8));
        compactSubtitles.add(
          Text(
            '${song.ourBPM} BPM',
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        );
      }
    } else if (item is BandItemAdapter) {
      // Compact band shows nothing in subtitle
    } else if (item is SetlistItemAdapter) {
      final setlist = item as SetlistItemAdapter;
      compactSubtitles.add(
        Text(
          '${setlist.songIdsLength} songs',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return Row(children: compactSubtitles);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
