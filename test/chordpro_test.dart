import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/utils/chordpro.dart';

void main() {
  group('parseChordProLine', () {
    test('splits chords and lyrics in order', () {
      final segs = parseChordProLine('[Am]Twinkle [F]little [C]star');
      expect(segs, [
        (chord: 'Am', text: 'Twinkle '),
        (chord: 'F', text: 'little '),
        (chord: 'C', text: 'star'),
      ]);
    });

    test('leading text before the first chord has a null chord', () {
      final segs = parseChordProLine('Twinkle [F]little');
      expect(segs, [
        (chord: null, text: 'Twinkle '),
        (chord: 'F', text: 'little'),
      ]);
    });

    test('plain line with no chords', () {
      expect(parseChordProLine('just words'), [(chord: null, text: 'just words')]);
    });

    test('empty line', () {
      expect(parseChordProLine(''), isEmpty);
    });
  });

  group('transposeChord', () {
    test('up a tone, minor quality preserved', () {
      expect(transposeChord('Am', 2), 'Bm');
    });

    test('up a semitone', () {
      expect(transposeChord('C', 1), 'C#');
    });

    test('down a semitone wraps to B', () {
      expect(transposeChord('C', -1), 'B');
    });

    test('flat spelling is kept', () {
      expect(transposeChord('Bb', 2), 'C');
      expect(transposeChord('Eb', -1), 'D');
    });

    test('slash bass transposes both parts', () {
      expect(transposeChord('C/G', 2), 'D/A');
    });

    test('suffix preserved', () {
      expect(transposeChord('F#m7', 1), 'Gm7');
    });

    test('non-chord token left alone', () {
      expect(transposeChord('N.C.', 5), 'N.C.');
    });
  });

  group('chordsOverLyrics', () {
    test('aligns chords above the syllable they precede', () {
      final r = chordsOverLyrics('[Am]Twinkle [F]little [C]star');
      expect(r.lyrics, 'Twinkle little star');
      // Each chord sits at the column where its lyric segment begins.
      expect(r.chords.indexOf('Am'), r.lyrics.indexOf('Twinkle'));
      expect(r.chords.indexOf('F'), r.lyrics.indexOf('little'));
      expect(r.chords.indexOf('C'), r.lyrics.indexOf('star'));
    });

    test('line with no chords yields an empty chord line', () {
      final r = chordsOverLyrics('just words');
      expect(r.chords, '');
      expect(r.lyrics, 'just words');
    });
  });

  group('parseSongSections', () {
    test('splits on bracketed/colon headers', () {
      final s = parseSongSections(
        '[Verse 1]\n[Am]Twinkle [F]star\n\n'
        'Chorus:\n[C]How I [G]wonder',
      );
      expect(s.length, 2);
      expect(s[0].name, 'Verse 1');
      expect(s[0].chart, '[Am]Twinkle [F]star');
      expect(s[1].name, 'Chorus');
      expect(s[1].chart, '[C]How I [G]wonder');
    });

    test('no headers => single default Verse', () {
      final s = parseSongSections('[Am]just a line\nanother line');
      expect(s.length, 1);
      expect(s[0].name, 'Verse');
      expect(s[0].chart, '[Am]just a line\nanother line');
    });

    test('chord-only line is not a header; directives ignored', () {
      final s = parseSongSections('{title: Song}\n{soc}\n[Am] [G]\nwords');
      expect(s.length, 1);
      expect(s[0].name, 'Chorus'); // from {soc}
      expect(s[0].chart, '[Am] [G]\nwords');
    });

    test('empty input yields no sections', () {
      expect(parseSongSections('   \n\n'), isEmpty);
    });
  });

  group('transposeChordChart', () {
    test('zero is a no-op', () {
      const chart = '[Am]Twinkle [F]little [C]star';
      expect(transposeChordChart(chart, 0), chart);
    });

    test('lyrics untouched, chords shifted', () {
      expect(
        transposeChordChart('[Am]Twinkle [F]star', 2),
        '[Bm]Twinkle [G]star',
      );
    });

    test('+12 semitones round-trips to the same roots', () {
      const chart = '[Am]Twinkle [F]little [C/G]star';
      expect(transposeChordChart(chart, 12), chart);
    });
  });

  group('keyToScale', () {
    test('minor key', () {
      final s = keyToScale('Am');
      expect(s.root, 'A');
      expect(s.accidental, isNull);
      expect(s.quality, 'minor');
    });

    test('sharp minor', () {
      final s = keyToScale('F#m');
      expect(s.root, 'F');
      expect(s.accidental, '#');
      expect(s.quality, 'minor');
    });

    test('flat major', () {
      final s = keyToScale('Bb');
      expect(s.root, 'B');
      expect(s.accidental, 'b');
      expect(s.quality, 'major');
    });

    test('plain major', () {
      final s = keyToScale('C');
      expect(s.root, 'C');
      expect(s.accidental, isNull);
      expect(s.quality, 'major');
    });

    test('maj7 is major, not minor', () {
      expect(keyToScale('Cmaj7').quality, 'major');
    });
  });

  group('songMapSummary', () {
    test('collapses consecutive repeats', () {
      expect(
        songMapSummary(['Intro', 'Verse', 'Chorus', 'Chorus', 'Bridge']),
        'Intro · Verse · Chorus ×2 · Bridge',
      );
    });
  });

  group('songToChordPro / chordProToSong round-trip', () {
    Song blank() => Song(
      id: 'x',
      title: '',
      artist: '',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

    test('preserves metadata, song map and section charts', () {
      final song = blank().copyWith(
        title: 'Zombie',
        artist: 'The Cranberries',
        ourKey: 'Em',
        ourBPM: 84,
        accentBeats: 4,
        sections: [
          Section(
            id: 's1',
            name: 'Verse 1',
            notes: 'soft',
            chordChart: '[Em]Another [C]head',
          ),
          Section(id: 's2', name: 'Chorus', chordChart: '[Em]In your [C]head'),
        ],
      );
      final parsed = chordProToSong(songToChordPro(song), base: blank());

      expect(parsed.song.title, 'Zombie');
      expect(parsed.song.artist, 'The Cranberries');
      expect(parsed.song.ourKey, 'Em');
      expect(parsed.song.ourBPM, 84);
      expect(parsed.song.accentBeats, 4);
      expect(parsed.sections.map((s) => s.name).toList(), [
        'Verse 1',
        'Chorus',
      ]);
      expect(parsed.sections[0].chordChart, '[Em]Another [C]head');
      expect(parsed.sections[0].notes, 'soft');
      expect(parsed.sections[1].chordChart, '[Em]In your [C]head');
    });

    test('unknown directives are preserved, not dropped', () {
      final text =
          '${songToChordPro(blank().copyWith(title: 'T'))}\n'
          '{x_customapp_foo: bar}';
      final parsed = chordProToSong(text, base: blank());
      expect(
        parsed.unknownDirectives.any((d) => d.contains('x_customapp_foo')),
        isTrue,
      );
    });
  });
}
