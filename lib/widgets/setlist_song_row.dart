import 'package:flutter/material.dart';

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
  });

  final int index;
  final Song? song;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final song = this.song;
    return Card(
      margin: const EdgeInsets.only(bottom: MonoPulseSpacing.md),
      child: ListTile(
        leading:
            leading ??
            CircleAvatar(
              backgroundColor: context.mp.surfaceRaised,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: context.mp.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        title: Text(
          song?.title ?? 'Unavailable song',
          style: TextStyle(color: context.mp.textPrimary),
        ),
        subtitle: song != null
            ? Text(
                song.artist,
                style: TextStyle(color: context.mp.textSecondary),
              )
            : null,
        trailing: song == null ? null : trailing,
      ),
    );
  }
}
