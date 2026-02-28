/// Unit tests for song normalization.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/services/matching/song_normalizer.dart';

void main() {
  group('SongNormalizer.normalizeTitle', () {
    test('converts to lowercase', () {
      expect(
        SongNormalizer.normalizeTitle('BOHEMIAN RHAPSODY'),
        equals('bohemian rhapsody'),
      );
    });

    test('removes special characters', () {
      expect(
        SongNormalizer.normalizeTitle("It's Alright!"),
        equals('it s alright'),
      );
      expect(SongNormalizer.normalizeTitle('Song #1'), equals('song 1'));
    });

    test('removes feat. suffix', () {
      expect(
        SongNormalizer.normalizeTitle('Song feat. Artist'),
        equals('song'),
      );
      expect(SongNormalizer.normalizeTitle('Song feat Artist'), equals('song'));
    });

    test('removes ft. suffix', () {
      expect(SongNormalizer.normalizeTitle('Song ft. John'), equals('song'));
    });

    test('removes featuring suffix', () {
      expect(
        SongNormalizer.normalizeTitle('Song featuring Mary'),
        equals('song'),
      );
    });

    test('removes live parenthetical', () {
      expect(SongNormalizer.normalizeTitle('Song (Live)'), equals('song'));
      expect(
        SongNormalizer.normalizeTitle('Song (Live at Wembley)'),
        equals('song'),
      );
      expect(
        SongNormalizer.normalizeTitle('Song (Live Version)'),
        equals('song'),
      );
    });

    test('removes acoustic parenthetical', () {
      expect(SongNormalizer.normalizeTitle('Song (Acoustic)'), equals('song'));
      expect(
        SongNormalizer.normalizeTitle('Song (Acoustic Version)'),
        equals('song'),
      );
    });

    test('removes remastered parenthetical', () {
      expect(
        SongNormalizer.normalizeTitle('Song (Remastered)'),
        equals('song'),
      );
    });

    test('removes remix parenthetical', () {
      expect(SongNormalizer.normalizeTitle('Song (Remix)'), equals('song'));
    });

    test('removes radio edit parenthetical', () {
      expect(
        SongNormalizer.normalizeTitle('Song (Radio Edit)'),
        equals('song'),
      );
    });

    test('normalizes whitespace', () {
      expect(
        SongNormalizer.normalizeTitle('  Song   Title  '),
        equals('song title'),
      );
    });

    test('handles empty string', () {
      expect(SongNormalizer.normalizeTitle(''), equals(''));
    });

    test('complex example: Bohemian Rhapsody typo', () {
      expect(
        SongNormalizer.normalizeTitle('Bohemian Rapsody'),
        equals('bohemian rapsody'),
      );
    });
  });

  group('SongNormalizer.normalizeArtist', () {
    test('removes The prefix', () {
      expect(SongNormalizer.normalizeArtist('The Beatles'), equals('beatles'));
      expect(
        SongNormalizer.normalizeArtist('The Rolling Stones'),
        equals('rolling stones'),
      );
    });

    test('does not remove The from middle', () {
      expect(
        SongNormalizer.normalizeArtist('Talking Heads'),
        equals('talking heads'),
      );
    });

    test('normalizes and to ampersand', () {
      expect(
        SongNormalizer.normalizeArtist('Simon and Garfunkel'),
        equals('simon&garfunkel'),
      );
    });

    test('normalizes ampersand spacing', () {
      expect(
        SongNormalizer.normalizeArtist('Hall & Oates'),
        equals('hall&oates'),
      );
    });

    test('handles empty string', () {
      expect(SongNormalizer.normalizeArtist(''), equals(''));
    });
  });
}
