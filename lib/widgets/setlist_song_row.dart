import 'package:material_ui/material_ui.dart';

import '../models/song.dart';
import '../theme/mono_pulse_theme.dart';

/// A single setlist song row: a numbered avatar (or a custom [leading],
/// e.g. a drag handle), the song's title/artist, and — only when the song
/// actually resolves — [trailing] content such as key/BPM badges or action
/// icons.
///
/// When [song] is null the entry is an "unavailable song": a setlist item
/// whose songId doesn't resolve against the current song corpus. It still
/// renders a row (title "Unavailable song", no subtitle/trailing) instead of
/// being silently dropped from the list — an unresolvable entry is still an
/// entry. Shared by the read-only `SetlistViewScreen` and the editable
/// `CreateSetlistScreen` so both render orphaned entries identically.
class SetlistSongRow extends StatelessWidget {
  const SetlistSongRow({
    required this.index,
    required this.song,
    super.key,
    this.leading,
    this.trailing,
    this.onTap,
    this.performers,
    this.savedTitle,
    this.savedArtist,
    this.loadFailed = false,
    this.isCurrent = false,
  });

  final int index;
  final Song? song;
  final String? savedTitle;
  final String? savedArtist;
  final bool loadFailed;
  final Widget? leading;
  final Widget? trailing;

  /// Who plays this song, pre-formatted (see `performerLabel`). Null/empty
  /// hides the line entirely.
  final String? performers;

  /// Marks the currently selected song with a muted petrol fill and marker.
  final bool isCurrent;

  /// Tap handler; only wired when [song] resolves (an "Unavailable song" row
  /// stays inert, same guard as [trailing]).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final song = this.song;
    final performers = this.performers;
    final showPerformers =
        song != null && performers != null && performers.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: song == null ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.only(
            top: MonoPulseSpacing.sm,
            bottom: MonoPulseSpacing.sm,
            right: MonoPulseSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isCurrent ? MonoPulseColors.selection : null,
            border: Border(bottom: BorderSide(color: context.mp.borderSubtle)),
          ),
          child: Row(
            children: [
              if (isCurrent)
                Container(
                  width: 3,
                  height: 40,
                  color: MonoPulseColors.selectionInk,
                )
              else
                const SizedBox(width: 3),
              SizedBox(
                width: 44,
                child: Center(
                  child:
                      leading ??
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: context.mp.textTertiary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                ),
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song?.title ??
                          (savedTitle?.trim().isNotEmpty == true
                              ? savedTitle!
                              : 'Unavailable song'),
                      style: TextStyle(
                        color: context.mp.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (song == null) ...[
                      if (savedArtist?.trim().isNotEmpty == true)
                        Text(
                          savedArtist!,
                          style: TextStyle(color: context.mp.textSecondary),
                        ),
                      Text(
                        loadFailed
                            ? 'Could not load songs. Try again later.'
                            : 'Deleted or no longer shared with you.',
                        style: TextStyle(color: context.mp.textSecondary),
                      ),
                    ],
                    if (song != null) ...[
                      Text(
                        song.artist,
                        style: TextStyle(color: context.mp.textSecondary),
                      ),
                      if (showPerformers)
                        Text(
                          performers,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mp.textTertiary,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (song != null && trailing != null) ...[
                const SizedBox(width: MonoPulseSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// BPM column of a setlist row: fixed width for three digits, right-aligned,
/// kept when [bpm] is null, so Play and key line up in every row.
class SetlistBpmSlot extends StatelessWidget {
  const SetlistBpmSlot(this.bpm, {this.color, super.key});

  final int? bpm;
  final Color? color;

  static const width = 40.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: bpm == null
          ? null
          : Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$bpm',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
    );
  }
}
