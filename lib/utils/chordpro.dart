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

/// Section-header keywords used to split pasted text into sections.
const _headerWords = [
  'intro', 'verse', 'prechorus', 'pre-chorus', 'chorus', 'bridge', 'outro',
  'instrumental', 'solo', 'interlude', 'refrain', 'hook', 'breakdown', 'coda',
  'ending', 'tag', 'pause',
];

bool _isHeaderWord(String s) {
  final first =
      s.trim().toLowerCase().split(RegExp(r'\s+')).first.replaceAll('-', '');
  return _headerWords.map((w) => w.replaceAll('-', '')).contains(first);
}

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Returns the section name if [line] is a header, else null. Recognizes
/// ChordPro start directives ({start_of_chorus}/{soc}, {comment: X}), bracketed
/// headers ([Verse 1]), "Chorus:" and bare "Verse 2" — but only when the label
/// is a known section word, so chord lines like `[Am]` are never headers.
String? _sectionHeader(String line) {
  final t = line.trim();
  if (t.isEmpty) return null;

  final directive = RegExp(r'^\{\s*(.+?)\s*\}$').firstMatch(t);
  if (directive != null) {
    final inner = directive.group(1)!.toLowerCase();
    final start = RegExp(r'^(?:start_of_|so)([a-z_]+)$').firstMatch(inner);
    if (start != null) {
      const abbr = {'v': 'Verse', 'c': 'Chorus', 'b': 'Bridge', 't': 'Tag'};
      final kind = start.group(1)!;
      return abbr[kind] ?? _titleCase(kind.replaceAll('_', ' '));
    }
    final comment = RegExp(r'^(?:comment|c)\s*:\s*(.+)$').firstMatch(inner);
    if (comment != null) return _titleCase(comment.group(1)!);
    return null; // other directive (title/key/...) — not a header
  }

  final bracket = RegExp(r'^\[(.+)\]$').firstMatch(t);
  if (bracket != null && _isHeaderWord(bracket.group(1)!)) {
    return _titleCase(bracket.group(1)!.trim());
  }
  final colon = RegExp(r'^([A-Za-z][A-Za-z \-]{0,20}?)\s*:$').firstMatch(t);
  if (colon != null && _isHeaderWord(colon.group(1)!)) {
    return _titleCase(colon.group(1)!.trim());
  }
  final bare = RegExp(r'^[A-Za-z][A-Za-z\- ]*\d*$').firstMatch(t);
  if (bare != null && _isHeaderWord(t)) return _titleCase(t);

  return null;
}

/// Splits pasted ChordPro/plain text into named sections, each with a ChordPro
/// [chart] string. Pure `{directive}` lines (title/key/...) are dropped; content
/// before the first header lands in a default "Verse". Empty sections are
/// omitted. Used by paste-to-import.
List<({String name, String chart})> parseSongSections(String text) {
  final names = <String>[];
  final buffers = <List<String>>[];
  void startSection(String name) {
    names.add(name);
    buffers.add(<String>[]);
  }

  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    final header = _sectionHeader(line);
    if (header != null) {
      startSection(header);
      continue;
    }
    if (RegExp(r'^\{.*\}$').hasMatch(line.trim())) continue; // stray directive
    if (names.isEmpty) startSection('Verse');
    buffers.last.add(line);
  }

  final out = <({String name, String chart})>[];
  for (var i = 0; i < names.length; i++) {
    final chart = buffers[i].join('\n').trim();
    if (chart.isNotEmpty) out.add((name: names[i], chart: chart));
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
