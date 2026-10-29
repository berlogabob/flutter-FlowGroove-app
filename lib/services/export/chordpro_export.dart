import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/song.dart';
import '../../utils/chordpro.dart';
import '../analytics_service.dart';

/// Exports a song's "our version" as a standard ChordPro `.cho` file and opens
/// the share sheet. Reuses [songToChordPro] (directives + `[Chord]lyric` lines)
/// and the same share_plus path as the CSV export.
Future<bool> shareSongChordPro(Song song) async {
  final ok = await shareChordProText(songToChordPro(song), song.title);
  if (ok) {
    unawaited(
      AnalyticsService.logSongShared(songId: song.id, shareMethod: 'chordpro'),
    );
  }
  return ok;
}

/// Shares an already-serialized ChordPro document (e.g. the song editor's live
/// text) as a `.cho` file. (#79 — export from the editor menu.)
Future<bool> shareChordProText(String text, String title) async {
  try {
    final fileName = '${_sanitize(title)}.cho';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(text),
            name: fileName,
            mimeType: 'text/plain',
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'FlowGroove — $title',
      ),
    );
    return true;
  } catch (e, stackTrace) {
    debugPrint('ChordPro share failed: $e\n$stackTrace');
    return false;
  }
}

String _sanitize(String title) {
  final cleaned = title.trim().replaceAll(RegExp(r'[^\w\s-]'), '').trim();
  return cleaned.isEmpty ? 'song' : cleaned;
}
