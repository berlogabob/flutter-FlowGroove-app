import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/setlist.dart';
import '../../models/setlist_break_type.dart';
import '../../models/song.dart';
import '../../utils/snackbar.dart';
import '../../widgets/share_sheet.dart';

/// Shared setlist share body + delivery modes (#128) — one text builder for
/// both the personal and band screens, so "Share" and "Copy links" behave
/// identically everywhere.
String setlistShareText(Setlist setlist, List<Song> songs) {
  final buffer = StringBuffer();
  buffer.writeln('🎵 ${setlist.name}');
  if (setlist.description != null) buffer.writeln(setlist.description);
  buffer.writeln();
  buffer.writeln('Songs:');
  final songById = {for (final s in songs) s.id: s};
  var n = 0; // per-section song number, reset by each break
  for (final item in setlist.effectiveItems) {
    if (item.isBreak) {
      buffer.writeln();
      buffer.writeln(
        '— ${SetlistBreakType.labelFor(item.breakType, item.breakLabel).toUpperCase()} —',
      );
      n = 0;
      continue;
    }
    final song = songById[item.songId];
    if (song == null) continue;
    n++;
    buffer.writeln('$n. ${song.title} - ${song.artist}');
    if (song.spotifyUrl != null) {
      buffer.writeln('   🎧 ${song.spotifyUrl}');
    } else {
      final searchUrl = Uri.encodeComponent('${song.title} ${song.artist}');
      buffer.writeln('   🔍 https://open.spotify.com/search/$searchUrl');
    }
  }
  buffer.writeln();
  buffer.writeln('Created with FlowGroove');
  return buffer.toString();
}

/// Opens the native share sheet with the setlist links body.
void shareSetlistLinks(BuildContext context, Setlist setlist, List<Song> songs) {
  showShareSheet(context, setlistShareText(setlist, songs), subject: setlist.name);
}

/// Copies the setlist links body to the clipboard with a confirmation.
Future<void> copySetlistLinks(
  BuildContext context,
  Setlist setlist,
  List<Song> songs,
) async {
  await Clipboard.setData(ClipboardData(text: setlistShareText(setlist, songs)));
  if (!context.mounted) return;
  showAppSnackBar(context, 'Setlist links copied to clipboard!');
}
