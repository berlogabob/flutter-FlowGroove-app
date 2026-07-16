import 'package:flutter/material.dart';

import '../../theme/mono_pulse_theme.dart';
import '../band_avatar.dart';
import 'adapters/band_item_adapter.dart';
import 'adapters/setlist_item_adapter.dart';
import 'adapters/song_item_adapter.dart';
import 'unified_item_model.dart';
import 'unified_item_trailing_actions.dart';

/// Unified card for Songs, Bands and Setlists (#86 redesign).
///
/// Two decks instead of a ListTile: the title deck owns the card's full
/// width (no trailing cluster stealing room — the old layout squashed long
/// titles on phones), and the meta rail below carries badges on the left and
/// the actions on the right. Songs always reserve the rail so cards stay the
/// same height whether or not key/BPM exist (audit P2-14); the key chip uses
/// the same orange treatment everywhere (audit P2-4).
class UnifiedItemCard<T extends UnifiedItemModel> extends StatelessWidget {
  const UnifiedItemCard({
    required this.item,
    super.key,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.showCompact = false,
    this.customActions = const [],
  });
  final T item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool showCompact;
  final List<UnifiedItemAction> customActions;

  @override
  Widget build(BuildContext context) {
    final actions = UnifiedItemTrailingActions(
      item: item,
      onEdit: onEdit,
      onDelete: onDelete,
      customActions: customActions,
      showCompact: showCompact,
    );

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: MonoPulseSpacing.lg,
        vertical: MonoPulseSpacing.sm,
      ),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MonoPulseSpacing.lg,
            vertical: showCompact ? MonoPulseSpacing.sm : MonoPulseSpacing.md,
          ),
          child: Row(
            children: [
              ..._leading(context),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title deck: full card width, nothing competes with it.
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: showCompact
                          ? MonoPulseTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            )
                          : MonoPulseTypography.titleLarge.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                    ),
                    if (!showCompact && _subtitleText() != null)
                      Text(
                        _subtitleText()!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: MonoPulseColors.textSecondary,
                        ),
                      ),
                    SizedBox(height: showCompact ? 0 : MonoPulseSpacing.xs),
                    // Meta rail: badges left, actions right — actions live in
                    // the thumb-friendly lower half, off the title's row.
                    Row(
                      children: [
                        Expanded(child: _metaRail(context)),
                        actions,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _leading(BuildContext context) {
    // Songs get no avatar — titles need the room on phones.
    if (item is SongItemAdapter) return const [];
    Widget avatar;
    if (item is BandItemAdapter) {
      final band = (item as BandItemAdapter).band;
      avatar = BandAvatar(
        photoURL: band.photoURL,
        bandName: band.name,
        radius: 20,
      );
    } else {
      avatar = const CircleAvatar(
        backgroundColor: MonoPulseColors.surfaceRaised,
        child: Icon(Icons.playlist_play, color: MonoPulseColors.accentOrange),
      );
    }
    return [avatar, const SizedBox(width: MonoPulseSpacing.md)];
  }

  /// One-line secondary text under the title (artist / description).
  String? _subtitleText() {
    final text = switch (item) {
      SongItemAdapter(:final subtitle) => subtitle,
      BandItemAdapter(:final subtitle) => subtitle,
      _ => null,
    };
    return (text?.isNotEmpty ?? false) ? text : null;
  }

  /// The badge/attribution line. Songs always render the rail (reserved
  /// height); bands/setlists show their counts here.
  Widget _metaRail(BuildContext context) {
    if (item is SongItemAdapter) {
      final song = item as SongItemAdapter;
      final displayKey = song.ourKey ?? song.originalKey;
      final displayBPM = song.displayBPM;
      return Wrap(
        spacing: MonoPulseSpacing.md,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _keyChip(displayKey),
          if (displayBPM != null)
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
                  '$displayBPM',
                  style: MonoPulseTypography.bodySmall.copyWith(
                    color: MonoPulseColors.accentOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          if (song.contributedBy != null || song.isCopy)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.content_copy,
                  size: 12,
                  color: MonoPulseColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  song.contributedBy != null
                      ? 'Added by ${song.contributedBy}'
                      : 'Shared to band',
                  style: MonoPulseTypography.labelSmall.copyWith(
                    color: MonoPulseColors.textTertiary,
                  ),
                ),
              ],
            ),
        ],
      );
    }
    if (item is BandItemAdapter) {
      final membersCount = (item as BandItemAdapter).membersCount;
      return Text(
        '$membersCount ${membersCount == 1 ? 'member' : 'members'}',
        style: MonoPulseTypography.bodySmall,
      );
    }
    if (item is SetlistItemAdapter) {
      final adapter = item as SetlistItemAdapter;
      final songCount = adapter.songIdsLength;
      final setlist = adapter.setlist;
      return Text(
        [
          '$songCount ${songCount == 1 ? 'song' : 'songs'}',
          if (setlist.eventDateTime != null) setlist.formattedEventDate,
        ].join(' · '),
        style: MonoPulseTypography.bodySmall,
      );
    }
    return const SizedBox.shrink();
  }

  /// Key chip — same treatment as the setlist view badges (orange on
  /// orange10); '—' keeps the slot when the key is unset, so card heights
  /// never jump between rows.
  Widget _keyChip(String? key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: key != null
            ? MonoPulseColors.accentOrange10
            : MonoPulseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        key ?? '—',
        style: MonoPulseTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: key != null
              ? MonoPulseColors.accentOrange
              : MonoPulseColors.textTertiary,
        ),
      ),
    );
  }
}
