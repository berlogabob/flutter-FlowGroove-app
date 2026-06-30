/// Minimal ChordPro helpers: parse a line into chord/lyric segments and
/// transpose the chords in a chart. Self-contained — one parser powers the
/// editor preview, the performance view, and (later) export.
///
/// ChordPro puts a chord in square brackets immediately before the syllable it
/// belongs to: `[Am]Twinkle [F]little [C]star`.
library;

/// A piece of a lyric line: [text] optionally preceded by a [chord].
typedef ChordSegment = ({String? chord, String text});

const _sharp = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];
const _flatToSharp = {
  'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#', 'Cb': 'B', 'Fb': 'E',
};
const _sharpToFlat = {
  'C#': 'Db', 'D#': 'Eb', 'F#': 'Gb', 'G#': 'Ab', 'A#': 'Bb',
};

final _chordToken = RegExp(r'\[([^\]]*)\]');
final _root = RegExp(r'^([A-G][#b]?)(.*)$');

/// Splits one ChordPro line into ordered segments. Text before the first chord
/// yields a segment with `chord == null`; each chord token starts a new segment
/// whose text runs to the next chord (or end of line).
List<ChordSegment> parseChordProLine(String line) {
  final matches = _chordToken.allMatches(line).toList();
  if (matches.isEmpty) {
    return line.isEmpty ? const [] : [(chord: null, text: line)];
  }
  final out = <ChordSegment>[];
  if (matches.first.start > 0) {
    out.add((chord: null, text: line.substring(0, matches.first.start)));
  }
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final end = i + 1 < matches.length ? matches[i + 1].start : line.length;
    out.add((chord: m.group(1)!, text: line.substring(m.end, end)));
  }
  return out;
}

/// Renders one ChordPro line as two aligned monospace lines: a chord line whose
/// chords sit above the syllable they precede, and the bare lyric line. Used for
/// PDF/plain-text export where per-segment widgets aren't available.
({String chords, String lyrics}) chordsOverLyrics(String line) {
  final lyrics = StringBuffer();
  final chords = StringBuffer();
  for (final seg in parseChordProLine(line)) {
    final chord = seg.chord;
    if (chord != null && chord.isNotEmpty) {
      while (chords.length < lyrics.length) {
        chords.write(' ');
      }
      chords.write('$chord ');
    }
    lyrics.write(seg.text);
  }
  return (chords: chords.toString().trimRight(), lyrics: lyrics.toString());
}

/// Transposes every `[chord]` in a chart by [semitones] (lyrics untouched).
String transposeChordChart(String chart, int semitones) {
  if (semitones == 0) return chart;
  return chart.replaceAllMapped(
    _chordToken,
    (m) => '[${transposeChord(m.group(1)!, semitones)}]',
  );
}

/// Transposes a single chord symbol, preserving its quality/suffix and any
/// slash-bass. Unrecognizable tokens (e.g. `N.C.`) are returned unchanged.
String transposeChord(String chord, int semitones) {
  if (chord.isEmpty) return chord;

  final slash = chord.indexOf('/');
  if (slash != -1) {
    return '${transposeChord(chord.substring(0, slash), semitones)}'
        '/${transposeChord(chord.substring(slash + 1), semitones)}';
  }

  final m = _root.firstMatch(chord);
  if (m == null) return chord;
  final rawRoot = m.group(1)!;
  final suffix = m.group(2)!;

  final normalized = _flatToSharp[rawRoot] ?? rawRoot;
  final idx = _sharp.indexOf(normalized);
  if (idx == -1) return chord;

  var newIdx = (idx + semitones) % 12;
  if (newIdx < 0) newIdx += 12;
  var newRoot = _sharp[newIdx];

  // Keep flat spelling if the source chord was flat (readability).
  final wasFlat = rawRoot.length == 2 && rawRoot[1] == 'b';
  if (wasFlat) newRoot = _sharpToFlat[newRoot] ?? newRoot;

  return '$newRoot$suffix';
}
