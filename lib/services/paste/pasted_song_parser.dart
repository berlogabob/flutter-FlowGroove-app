// ignore_for_file: valid_regexps
/// Turns pasted plain text (Notes, Keep, messengers, documents) into songs.
library;

import 'package:flutter/foundation.dart';

/// One recognised line: a title and an optional artist.
@immutable
class PastedSong {
  const PastedSong(this.title, [this.artist]);

  final String title;
  final String? artist;

  @override
  bool operator ==(Object other) =>
      other is PastedSong && other.title == title && other.artist == artist;

  @override
  int get hashCode => Object.hash(title, artist);

  @override
  String toString() => 'PastedSong($title, $artist)';
}

class PastedSongs {
  const PastedSongs(this.songs, {this.truncated = false});

  final List<PastedSong> songs;

  /// True when more than [maxPastedSongs] songs were pasted.
  final bool truncated;
}

const maxPastedSongs = 200;

// Leading list markers, stripped repeatedly. Dashes and asterisks need a
// space after them; "1." / "1)" / "1️⃣" need not; a bare number needs a leading
// zero ("01 Title") so "99 Problems" and "7 Rings" stay whole.
// The analyzer does not know \p{Extended_Pictographic}; the VM does.
final _marker = RegExp(
  r'^(?:\[[ xX✓✔]?\]|[☐☑☒✓✔•·▪▫●○◦‣⁃]'
  r'|(?:[-–—*])(?=\s)|\d{1,3}️?⃣|\d{1,3}[.)]|0\d{1,2}(?=\s)'
  r'|[\p{Extended_Pictographic}️‍]+)\s*',
  unicode: true,
);
final _titleArtistSplit = RegExp(r'\s[-–—]\s');
final _hasContent = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// One song per non-empty line. See the rules in the paste-a-list feature:
/// markers stripped, split on the first spaced dash, exact duplicates dropped,
/// punctuation-only lines ignored, capped at [maxPastedSongs].
PastedSongs parsePastedSongs(String text) {
  final seen = <String>{};
  final songs = <PastedSong>[];
  var truncated = false;
  for (final raw in text.split(RegExp(r'\r\n|[\r\n  ]'))) {
    var line = raw.replaceAll('\t', ' ').trim();
    for (var m = _marker.firstMatch(line); m != null && m.end > 0;) {
      line = line.substring(m.end);
      m = _marker.firstMatch(line);
    }
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!_hasContent.hasMatch(line)) continue;

    final split = _titleArtistSplit.firstMatch(line);
    var title = line;
    String? artist;
    if (split != null) {
      final left = line.substring(0, split.start).trim();
      final right = line.substring(split.end).trim();
      if (left.isNotEmpty && right.isNotEmpty) {
        title = left;
        artist = right;
      }
    }
    if (!seen.add('${title.toLowerCase()}\n${artist?.toLowerCase() ?? ''}')) {
      continue;
    }
    if (songs.length >= maxPastedSongs) {
      truncated = true;
      break;
    }
    songs.add(PastedSong(title, artist));
  }
  return PastedSongs(songs, truncated: truncated);
}
