import 'package:flutter_test/flutter_test.dart';
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
}
