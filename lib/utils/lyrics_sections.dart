/// Split plain lyric text (e.g. from lyrics.ovh) into a rough song-part map.
///
/// ponytail: stanza heuristic — blank-line-separated blocks become sections; a
/// block whose exact text repeats is a "Chorus", unique blocks are "Verse N".
/// No chords (no free chord source exists); the upgrade path is paste-importing
/// a real ChordPro chart. Ceiling: naive exact-repeat detection — good enough
/// for a starting map the user then edits, not a musicological analysis.
///
/// Returns records of `(name, chart)` where `chart` is the stanza's lyric text
/// (goes into `Section.chordChart`). Empty/blank input → `[]`.
List<({String name, String chart})> lyricsToSections(String lyrics) {
  final stanzas = lyrics
      .split(RegExp(r'\n[ \t]*\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (stanzas.isEmpty) return [];

  // Count how often each stanza's exact text appears — repeats are choruses.
  final counts = <String, int>{};
  for (final s in stanzas) {
    counts[s] = (counts[s] ?? 0) + 1;
  }

  final out = <({String name, String chart})>[];
  final chorusLabel = <String, String>{}; // repeated stanza text -> its label
  var verseNo = 0;
  var chorusNo = 0;
  for (final s in stanzas) {
    String name;
    if (counts[s]! > 1) {
      // Reuse one label for every occurrence of the same chorus text; number
      // only when there are several *distinct* repeated blocks.
      name = chorusLabel.putIfAbsent(s, () {
        chorusNo++;
        return chorusNo == 1 ? 'Chorus' : 'Chorus $chorusNo';
      });
    } else {
      verseNo++;
      name = 'Verse $verseNo';
    }
    out.add((name: name, chart: s));
  }
  return out;
}
