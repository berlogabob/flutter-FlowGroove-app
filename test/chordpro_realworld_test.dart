import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/utils/chordpro.dart';

/// A real-world ChordPro chart (as a musician would paste it): plain `: Label`
/// section headers, a `{comment: Intro}` header with chords before the first
/// block, repeated choruses, and a slash-named final section. Guards that
/// [chordProToSong] syncs the header metadata AND the full section/song-map
/// structure — not just FlowGroove's own `songToChordPro` output.
const _backToBlack = r'''
{title: Back to Black}
{artist: Amy Winehouse}
{key: Dm}
{time: 4/4}
{tempo: 123}
{capo: 0}

{comment: Intro}
[Dm] [Gm] [Bb] [A7]

{start_of_verse: Verse 1}
[Dm]He left no time to [Gm]regret,
[Bb]Kept his dick wet, with his same old safe [A7]bet.
{end_of_verse}

{start_of_verse: Verse 2}
[Dm]You went back to what you [Gm]knew,
[Bb]So far removed from all that we went [A7]through.
{end_of_verse}

{start_of_chorus: Chorus}
[Dm]We only said goodbye with [Gm]words,
[Bb]I died a hundred [A7]times.
{end_of_chorus}

{start_of_verse: Verse 3}
[Dm]I love you [Gm]much, it's not enough,
{end_of_verse}

{start_of_chorus: Chorus}
[Dm]We only said goodbye with [Gm]words,
{end_of_chorus}

{start_of_chorus: Chorus}
[Dm]We only said goodbye with [Gm]words,
{end_of_chorus}

{start_of_bridge: Bridge}
[Dm]Black... [Bb]black,
{end_of_bridge}

{start_of_chorus: Chorus}
[Dm]We only said goodbye with [Gm]words,
{end_of_chorus}

{start_of_chorus: Final Chorus / Outro}
[Dm]We only said goodbye with [Gm]words,
[Dm]black
{end_of_chorus}
''';

void main() {
  Song blank() => Song(
    id: 'x',
    title: '',
    artist: '',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  group('chordProToSong on real-world ChordPro', () {
    final p = chordProToSong(_backToBlack, base: blank());

    test('syncs header metadata', () {
      expect(p.song.title, 'Back to Black');
      expect(p.song.artist, 'Amy Winehouse');
      expect(p.song.ourKey, 'Dm');
      expect(p.song.ourBPM, 123);
      expect(p.song.accentBeats, 4); // time 4/4
      expect(keyToScale(p.song.ourKey!).quality, 'minor'); // D minor
    });

    test('keeps real section labels incl. comment-Intro and slash names', () {
      expect(p.sections.map((s) => s.name).toList(), [
        'Intro',
        'Verse 1',
        'Verse 2',
        'Chorus',
        'Verse 3',
        'Chorus',
        'Chorus',
        'Bridge',
        'Chorus',
        'Final Chorus / Outro',
      ]);
    });

    test('captures the Intro chords that precede the first block', () {
      expect(p.sections.first.name, 'Intro');
      expect(p.sections.first.chordChart, '[Dm] [Gm] [Bb] [A7]');
    });

    test('derives the song map from section order', () {
      expect(
        songMapSummary(p.sections.map((s) => s.name).toList()),
        'Intro · Verse 1 · Verse 2 · Chorus · Verse 3 · Chorus ×2 · Bridge · '
        'Chorus · Final Chorus / Outro',
      );
    });
  });
}
