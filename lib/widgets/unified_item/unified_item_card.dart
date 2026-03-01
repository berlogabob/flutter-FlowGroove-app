import 'package:flutter/material.dart';
import 'unified_item_model.dart';
import 'unified_item_badge.dart';
import 'unified_item_trailing_actions.dart';
import 'adapters/song_item_adapter.dart';
import 'adapters/band_item_adapter.dart';
import 'adapters/setlist_item_adapter.dart';
import '../../theme/mono_pulse_theme.dart';

/// Unified card widget for displaying items (Song, Band, Setlist)
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
          onEdit: onEdit,
          onDelete: onDelete,
          customActions: customActions,
          showCompact: showCompact,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    IconData icon;
    bool isShared = false;

    if (item is SongItemAdapter) {
      icon = Icons.music_note;
      isShared = (item as SongItemAdapter).isShared;
    } else if (item is BandItemAdapter) {
      icon = Icons.groups;
    } else if (item is SetlistItemAdapter) {
      icon = Icons.playlist_play;
    } else {
      icon = Icons.info;
    }

    return CircleAvatar(
      backgroundColor: isShared
          ? const Color(0xFFFFE0B2)
          : const Color(0xFF1A1A1A),
      child: Icon(
        isShared ? Icons.content_copy : icon,
        color: isShared
            ? const Color(0xFFFF9800)
            : MonoPulseColors.accentOrange,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    if (showCompact) {
      return _buildCompactSubtitle();
    }

    final List<Widget> subtitleWidgets = [];

    // Song subtitle
    if (item is SongItemAdapter) {
      final song = item as SongItemAdapter;
      if (song.subtitle?.isNotEmpty == true) {
        subtitleWidgets.add(
          Text(
            song.subtitle!,
            style: const TextStyle(
              color: MonoPulseColors.textSecondary,
              fontSize: 12,
            ),
          ),
        );
      }

      // Add BPM and key badges - enhanced BPM display
      final List<Widget> badges = [];
      final displayBPM = song.displayBPM;
      if (displayBPM != null) {
        badges.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.speed,
                size: 14,
                color: MonoPulseColors.accentOrange,
              ),
              const SizedBox(width: 4),
              Text(
                '$displayBPM BPM',
                style: const TextStyle(
                  color: MonoPulseColors.accentOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
      if (song.ourKey != null) {
        badges.add(
          UnifiedItemBadge(
            text: song.ourKey!,
            color: MonoPulseColors.accentOrange,
          ),
        );
      } else if (song.originalKey != null) {
        badges.add(
          UnifiedItemBadge(
            text: song.originalKey!,
            color: MonoPulseColors.textTertiary,
          ),
        );
      }

      if (badges.isNotEmpty) {
        subtitleWidgets.add(Row(children: badges));
      }

      // Add attribution badge for copied songs
      if (song.isCopy) {
        subtitleWidgets.add(
          const Row(
            children: [
              Icon(
                Icons.content_copy,
                size: 12,
                color: MonoPulseColors.accentOrange,
              ),
              SizedBox(width: 4),
              Text(
                'Shared to band',
                style: TextStyle(
                  color: MonoPulseColors.accentOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
    }
    // Band subtitle
    // Band subtitle
    else if (item is BandItemAdapter) {
      final band = item as BandItemAdapter;
      if (band.subtitle?.isNotEmpty == true) {
        subtitleWidgets.add(
          Text(
            band.subtitle!,
            style: const TextStyle(
              color: MonoPulseColors.textSecondary,
              fontSize: 12,
            ),
          ),
        );
      }
      final membersCount = band.membersCount;
      subtitleWidgets.add(
        Text(
          '$membersCount ${membersCount == 1 ? 'member' : 'members'}',
          style: const TextStyle(
            color: MonoPulseColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );
    }
    // Setlist subtitle
    else if (item is SetlistItemAdapter) {
      final setlist = (item as SetlistItemAdapter).setlist;
      final songCount = setlist.songIds.length;
      subtitleWidgets.add(
        Text(
          '$songCount ${songCount == 1 ? 'song' : 'songs'}',
          style: const TextStyle(
            color: MonoPulseColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );

      if (setlist.eventDateTime != null) {
        subtitleWidgets.add(
          Text(
            setlist.formattedEventDate,
            style: const TextStyle(
              color: MonoPulseColors.textSecondary,
              fontSize: 12,
            ),
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
              color: MonoPulseColors.accentOrange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      } else if (song.originalKey != null) {
        compactSubtitles.add(
          Text(
            song.originalKey!,
            style: const TextStyle(
              color: MonoPulseColors.textTertiary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      }
      final displayBPM = song.displayBPM;
      if (displayBPM != null) {
        compactSubtitles.add(const SizedBox(width: 8));
        compactSubtitles.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.speed,
                size: 14,
                color: MonoPulseColors.accentOrange,
              ),
              const SizedBox(width: 2),
              Text(
                '$displayBPM BPM',
                style: const TextStyle(
                  color: MonoPulseColors.accentOrange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
    } else if (item is SetlistItemAdapter) {
      final setlist = item as SetlistItemAdapter;
      compactSubtitles.add(
        Text(
          '${setlist.songIdsLength} songs',
          style: const TextStyle(
            color: MonoPulseColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );
    }

    return Row(children: compactSubtitles);
  }
}
