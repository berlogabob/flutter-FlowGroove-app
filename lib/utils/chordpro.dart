/// Minimal ChordPro helpers: parse a line into chord/lyric segments and
/// transpose the chords in a chart. Self-contained — one parser powers the
/// editor preview, the performance view, and (later) export.
///
/// ChordPro puts a chord in square brackets immediately before the syllable it
/// belongs to: `[Am]Twinkle [F]little [C]star`.
library;

import '../models/section.dart';
import '../models/song.dart';

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

// ============================================================
// Song ⇄ ChordPro sync
// ------------------------------------------------------------
// The FlowGroove [Song] is the source of truth; ChordPro is its readable text
// layer. [songToChordPro] renders a song as one canonical document and
// [chordProToSong] reads one back — preserving directives it doesn't recognize
// so another app's data is never silently dropped on a round-trip.
// ============================================================

/// Splits a key symbol like `Am`, `F#m`, `Bb`, `C` into its parts. [quality] is
/// `minor` when the suffix starts with a lowercase `m` that isn't the start of
/// `maj`, otherwise `major`. Lets the UI show a scale next to the key without
/// adding a model field.
({String root, String? accidental, String quality}) keyToScale(String key) {
  final m = RegExp(r'^\s*([A-Ga-g])([#b])?(.*)$').firstMatch(key);
  if (m == null) {
    return (root: key.trim(), accidental: null, quality: 'major');
  }
  final suffix = m.group(3)!.trim();
  final isMinor = suffix.startsWith('m') && !suffix.startsWith('maj');
  return (
    root: m.group(1)!.toUpperCase(),
    accidental: m.group(2),
    quality: isMinor ? 'minor' : 'major',
  );
}

/// Collapses an ordered list of section names into a compact one-line song map,
/// merging consecutive repeats: `[Intro, Verse, Chorus, Chorus, Bridge]` →
/// `Intro · Verse · Chorus ×2 · Bridge`. Shared by the song card and PDF header.
String songMapSummary(List<String> names) {
  final parts = <String>[];
  final counts = <int>[];
  for (final raw in names) {
    final n = raw.trim();
    if (n.isEmpty) continue;
    if (parts.isNotEmpty && parts.last == n) {
      counts[counts.length - 1]++;
    } else {
      parts.add(n);
      counts.add(1);
    }
  }
  return [
    for (var i = 0; i < parts.length; i++)
      counts[i] > 1 ? '${parts[i]} ×${counts[i]}' : parts[i],
  ].join(' · ');
}

final _directiveLine = RegExp(
  r'^\s*\{\s*([A-Za-z_][\w-]*)\s*(?::\s*|\s+)(.*?)\s*\}\s*$',
  multiLine: true,
);

/// Reads `{name: value}` / `{name value}` directives from a ChordPro document
/// into a name→value map (lower-cased names, last wins). Value-less directives
/// like `{soc}` are skipped. Used to lift header metadata and `x_flowgroove_*`.
Map<String, String> parseDirectives(String text) {
  final out = <String, String>{};
  for (final m in _directiveLine.allMatches(text)) {
    out[m.group(1)!.toLowerCase()] = m.group(2)!;
  }
  return out;
}

/// Renders [song] as a single canonical ChordPro document: standard header
/// directives, an `x_flowgroove_*` snapshot of app-only data (original key, song
/// map), then one labelled block per section wrapping its `[* notes]` and chord
/// chart. Inverse of [chordProToSong].
String songToChordPro(Song song) {
  final b = StringBuffer();
  void directive(String name, Object? value) {
    final s = value?.toString().trim() ?? '';
    if (s.isNotEmpty) b.writeln('{$name: $s}');
  }

  directive('title', song.title);
  directive('artist', song.artist);
  directive('key', song.ourKey);
  directive('tempo', song.ourBPM);
  // The model carries no time-signature denominator; songs are treated as x/4.
  // ponytail: emit the numerator only; add a real denominator if 6/8 etc. matters.
  directive('time', '${song.accentBeats}/4');
  if (song.originalKey != null && song.originalKey != song.ourKey) {
    directive('x_flowgroove_original_key', song.originalKey);
  }
  if (song.sections.isNotEmpty) {
    directive(
      'x_flowgroove_song_map',
      song.sections.map((s) => s.name).join(' | '),
    );
  }
  final notes = song.notes?.trim() ?? '';
  if (notes.isNotEmpty) b.writeln('{comment: $notes}');

  for (final section in song.sections) {
    b.writeln();
    b.writeln('{start_of_verse: label="${section.name}"}');
    // Structured extras plain ChordPro can't carry (bars/colour) ride in an
    // x_ directive so they survive a pure-text round-trip and MCP.
    final extras = <String>[
      if (section.duration != 1) 'bars=${section.duration}',
      if (section.colorValue != null)
        'color=${(section.colorValue! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    ];
    if (extras.isNotEmpty) {
      b.writeln('{x_flowgroove_section: ${extras.join('; ')}}');
    }
    final sectionNotes = section.notes.trim();
    if (sectionNotes.isNotEmpty) {
      for (final n in sectionNotes.split('\n')) {
        b.writeln('[* ${n.trim()}]');
      }
    }
    final chart = section.chordChart?.trim() ?? '';
    if (chart.isNotEmpty) b.writeln(chart);
    b.writeln('{end_of_verse}');
  }
  return b.toString().trimRight();
}

/// The parts recovered from a ChordPro document by [chordProToSong].
class ChordProParse {
  ChordProParse({
    required this.song,
    required this.sections,
    required this.unknownDirectives,
  });

  /// [chordProToSong]'s `base` updated with the standard / `x_flowgroove_*`
  /// metadata found in the document.
  final Song song;

  /// Sections rebuilt from `{start_of_*}`…`{end_of_*}` blocks: the `label`
  /// becomes the name, `[* ...]` lines the notes, the rest the chord chart.
  final List<Section> sections;

  /// Directives that are neither standard ChordPro nor `x_flowgroove_*`, kept
  /// verbatim so a caller can re-emit them — ChordPro interop depends on not
  /// destroying data other apps wrote.
  final List<String> unknownDirectives;
}

const _knownDirectives = {
  'title', 'artist', 'key', 'tempo', 'time', 'capo', 'duration', 'tag',
  'comment', 'c', 'meta', 'subtitle', 'album', 'year', 'composer', 'lyricist',
  'x_flowgroove_original_key', 'x_flowgroove_song_map', 'x_flowgroove_section',
};

const _sectionAbbr = {'soc', 'sov', 'sob', 'sot', 'eoc', 'eov', 'eob', 'eot'};

bool _isSectionDirective(String name) =>
    name.startsWith('start_of_') ||
    name.startsWith('end_of_') ||
    _sectionAbbr.contains(name);

final _sectionStart = RegExp(
  r'^\s*\{\s*(?:start_of_(\w+)|so([bcvt]))\b\s*(?::\s*(.*?))?\s*\}\s*$',
);
final _sectionEnd = RegExp(r'^\s*\{\s*(?:end_of_\w+|eo[bcvt])\s*\}\s*$');
final _annotation = RegExp(r'^\s*\[\*\s*(.*?)\s*\]\s*$');
final _comment = RegExp(r'^\s*\{\s*(?:comment|c)\s*:\s*(.*?)\s*\}\s*$');
final _sectionExtra = RegExp(
  r'^\s*\{\s*x_flowgroove_section\s*:\s*(.*?)\s*\}\s*$',
  caseSensitive: false,
);
final _anyDirective = RegExp(r'^\s*\{.*\}\s*$');

/// Parses a full ChordPro document back onto [base]: standard directives update
/// title/artist/key/tempo/time, section blocks rebuild [Section]s, and any
/// unrecognized directive is preserved in [ChordProParse.unknownDirectives].
/// Inverse of [songToChordPro].
ChordProParse chordProToSong(String text, {required Song base}) {
  final dir = parseDirectives(text);

  const soAbbr = {'v': 'Verse', 'c': 'Chorus', 'b': 'Bridge', 't': 'Tab'};
  final sections = <Section>[];
  final songNotes = <String>[];
  String? name;
  var notes = '';
  int? curBars;
  int? curColor;
  final lines = <String>[];
  String? pendingLabel; // a {comment: X} not yet resolved to header vs song note

  void flush() {
    if (name == null) return;
    final chart = lines.join('\n').trim();
    final i = sections.length;
    final id = i < base.sections.length ? base.sections[i].id : 'cp_sec_$i';
    sections.add(
      Section(
        id: id,
        name: name,
        notes: notes,
        duration: curBars ?? 1,
        colorValue: curColor,
        chordChart: chart.isEmpty ? null : chart,
      ),
    );
    lines.clear();
    notes = '';
    curBars = null;
    curColor = null;
  }

  // Resolve a section label: `label="Foo"`, a plain `: Foo` after the directive,
  // else the section kind title-cased (`{start_of_bridge}` → `Bridge`).
  String labelFor(String? attr, String kind) {
    final a = (attr ?? '').trim();
    final quoted = RegExp(r'label\s*=\s*"([^"]*)"').firstMatch(a)?.group(1);
    final plain = quoted ?? (a.contains('=') ? '' : a);
    if (plain.trim().isNotEmpty) return plain.trim();
    return kind.isEmpty ? 'Verse' : _titleCase(kind.replaceAll('_', ' '));
  }

  for (final raw in text.split('\n')) {
    final line = raw.trimRight();

    final start = _sectionStart.firstMatch(line);
    if (start != null) {
      // A {comment: X} sitting just before a real block is a song-level note,
      // not a section header.
      if (pendingLabel != null) {
        songNotes.add(pendingLabel);
        pendingLabel = null;
      }
      flush();
      name = labelFor(
        start.group(3),
        start.group(1) ?? soAbbr[start.group(2)] ?? '',
      );
      continue;
    }
    if (_sectionEnd.hasMatch(line)) {
      flush();
      name = null;
      continue;
    }

    final comment = _comment.firstMatch(line);
    if (comment != null) {
      if (name == null) {
        pendingLabel = comment.group(1); // header for following chords, or a note
      } else {
        notes = notes.isEmpty
            ? comment.group(1)!
            : '$notes\n${comment.group(1)}';
      }
      continue;
    }

    final extra = _sectionExtra.firstMatch(line);
    if (extra != null) {
      if (name != null) {
        final body = extra.group(1)!;
        final bars = RegExp(r'bars\s*=\s*(\d+)').firstMatch(body);
        final color = RegExp(
          r'color\s*=\s*#?([0-9a-fA-F]{6})',
        ).firstMatch(body);
        if (bars != null) curBars = int.tryParse(bars.group(1)!);
        if (color != null) {
          curColor = 0xFF000000 | int.parse(color.group(1)!, radix: 16);
        }
      }
      continue;
    }

    final annot = _annotation.firstMatch(line);
    if (annot != null) {
      if (name != null) {
        notes = notes.isEmpty ? annot.group(1)! : '$notes\n${annot.group(1)}';
      }
      continue;
    }

    if (_anyDirective.hasMatch(line)) continue; // header / other directive

    if (line.trim().isEmpty) {
      if (name != null) lines.add(''); // keep blank lines inside a block
      continue;
    }

    // Real chord/lyric content. If we're not in a block yet, open an implicit
    // section — a preceding {comment: X} names it (e.g. Intro), else "Verse".
    if (name == null) {
      name = (pendingLabel != null && pendingLabel.trim().isNotEmpty)
          ? pendingLabel.trim()
          : 'Verse';
      pendingLabel = null;
    }
    lines.add(line);
  }
  if (pendingLabel != null) songNotes.add(pendingLabel);
  flush();

  final unknown = <String>[
    for (final m in _directiveLine.allMatches(text))
      if (!_knownDirectives.contains(m.group(1)!.toLowerCase()) &&
          !_isSectionDirective(m.group(1)!.toLowerCase()))
        m.group(0)!.trim(),
  ];

  // If the doc carried a song-map snapshot but no section blocks, rebuild
  // placeholder sections from it so the order survives the round-trip.
  var outSections = sections;
  if (outSections.isEmpty && dir['x_flowgroove_song_map'] != null) {
    final names = dir['x_flowgroove_song_map']!
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    outSections = [
      for (var i = 0; i < names.length; i++)
        Section(id: 'cp_map_$i', name: names[i]),
    ];
  }

  final song = base.copyWith(
    title: dir['title'] ?? base.title,
    artist: dir['artist'] ?? base.artist,
    ourKey: dir['key'] ?? base.ourKey,
    ourBPM: int.tryParse(dir['tempo'] ?? '') ?? base.ourBPM,
    originalKey: dir['x_flowgroove_original_key'] ?? base.originalKey,
    accentBeats:
        int.tryParse((dir['time'] ?? '').split('/').first.trim()) ??
        base.accentBeats,
    notes: songNotes.isNotEmpty ? songNotes.join('\n') : base.notes,
    sections: outSections.isNotEmpty ? outSections : base.sections,
  );

  return ChordProParse(
    song: song,
    sections: outSections,
    unknownDirectives: unknown,
  );
}

/// Merges freshly-[parsed] sections onto the [existing] ones, preserving the
/// structured extras plain ChordPro can't carry. Each parsed section is matched
/// greedily to the next unused existing section of the same name (in order); a
/// match keeps the existing `id` and any `duration`/`colorValue` the text didn't
/// specify, while taking the parsed name/notes/chordChart. Unmatched parsed
/// sections are new. This is what lets live text editing update chords and
/// re-order without wiping the map's structure.
List<Section> reconcileSections(
  List<Section> existing,
  List<Section> parsed,
) {
  final used = List<bool>.filled(existing.length, false);
  final out = <Section>[];
  for (final p in parsed) {
    var matched = -1;
    for (var i = 0; i < existing.length; i++) {
      if (!used[i] && existing[i].name == p.name) {
        matched = i;
        break;
      }
    }
    if (matched == -1) {
      out.add(p);
      continue;
    }
    used[matched] = true;
    final e = existing[matched];
    out.add(
      Section(
        id: e.id,
        name: p.name,
        notes: p.notes,
        duration: p.duration != 1 ? p.duration : e.duration,
        colorValue: p.colorValue ?? e.colorValue,
        chordChart: p.chordChart,
      ),
    );
  }
  return out;
}
