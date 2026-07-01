import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/song.dart';
import '../../utils/chordpro.dart';

/// Exports a song's "our version" as a standard ChordPro `.cho` file and opens
/// the share sheet. Reuses [songToChordPro] (directives + `[Chord]lyric` lines)
/// and the same share_plus path as the CSV export.
Future<bool> shareSongChordPro(Song song) async {
  try {
    final text = songToChordPro(song);
    final fileName = '${_sanitize(song.title)}.cho';
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
        subject: 'FlowGroove — ${song.title}',
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
