import 'package:flowgroove/utils/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chordProgression', () {
    test('extracts chords in order, dropping lyrics', () {
      expect(
        chordProgression('[Am]Twinkle [F]little [C]star [G]how'),
        ['Am', 'F', 'C', 'G'],
      );
    });

    test('collapses consecutive duplicates but keeps later repeats', () {
      expect(
        chordProgression('[C]la [C]la [G]la [C]back'),
        ['C', 'G', 'C'],
      );
    });

    test('spans lines and keeps complex chords', () {
      expect(
        chordProgression('[F#m]one [Csus4]two\n[Bb/D]three [Am7]four'),
        ['F#m', 'Csus4', 'Bb/D', 'Am7'],
      );
    });

    test('skips bracketed non-chords like section labels', () {
      // parseChordProLine accepts ANY [..] token; [Verse] and [Bridge] must
      // not leak into a progression ("Bridge" starts with a valid root B).
      expect(
        chordProgression('[Verse][C]one [Bridge][G]two [N.C.]stop'),
        ['C', 'G'],
      );
    });

    test('lyrics-only and empty charts produce nothing', () {
      expect(chordProgression('just words\nmore words'), isEmpty);
      expect(chordProgression(''), isEmpty);
    });

    test('handles Cyrillic lyrics around chords', () {
      expect(
        chordProgression('[Am]Группа [E]крови [Am]на рукаве'),
        ['Am', 'E', 'Am'],
      );
    });
  });
}
