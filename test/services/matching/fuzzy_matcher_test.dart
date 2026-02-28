/// Unit tests for fuzzy matching algorithms.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/services/matching/fuzzy_matcher.dart';

void main() {
  group('Levenshtein', () {
    group('distance', () {
      test('identical strings have distance 0', () {
        expect(Levenshtein.distance('hello', 'hello'), equals(0));
      });

      test('empty string distance equals length', () {
        expect(Levenshtein.distance('', 'hello'), equals(5));
        expect(Levenshtein.distance('hello', ''), equals(5));
      });

      test('single character substitution', () {
        expect(Levenshtein.distance('cat', 'bat'), equals(1));
      });

      test('single character insertion', () {
        expect(Levenshtein.distance('cat', 'cart'), equals(1));
      });

      test('single character deletion', () {
        expect(Levenshtein.distance('cart', 'cat'), equals(1));
      });

      test('transposition (Damerau)', () {
        expect(Levenshtein.distance('ab', 'ba'), equals(1));
      });

      test('classic example: kitten to sitting', () {
        expect(Levenshtein.distance('kitten', 'sitting'), equals(3));
      });

      test('typo tolerance: rhapsody vs rapsody', () {
        expect(Levenshtein.distance('rhapsody', 'rapsody'), equals(1));
      });
    });

    group('similarity', () {
      test('identical strings have similarity 1.0', () {
        expect(Levenshtein.similarity('hello', 'hello'), equals(1.0));
      });

      test('empty strings have similarity 1.0', () {
        expect(Levenshtein.similarity('', ''), equals(1.0));
      });

      test('similar strings have high similarity', () {
        final similarity = Levenshtein.similarity('rhapsody', 'rapsody');
        expect(similarity, closeTo(0.875, 0.01));
      });

      test('different strings have low similarity', () {
        final similarity = Levenshtein.similarity('abc', 'xyz');
        expect(similarity, equals(0.0));
      });
    });
  });

  group('JaroWinkler', () {
    test('identical strings have similarity 1.0', () {
      expect(JaroWinkler.similarity('hello', 'hello'), equals(1.0));
    });

    test('empty strings have similarity 0.0', () {
      expect(JaroWinkler.similarity('', 'hello'), equals(0.0));
    });

    test('strings with common prefix get boost', () {
      // Jaro-Winkler boosts score for common prefix
      final similarity = JaroWinkler.similarity(
        'bohemian rhapsody',
        'bohemian rapsody',
      );
      expect(similarity, greaterThan(0.9));
    });

    test('typo tolerance: rhapsody vs rapsody', () {
      final similarity = JaroWinkler.similarity('rhapsody', 'rapsody');
      expect(similarity, greaterThan(0.9));
    });

    test('different strings have low similarity', () {
      final similarity = JaroWinkler.similarity('abc', 'xyz');
      expect(similarity, equals(0.0));
    });
  });

  group('TokenSortRatio', () {
    test('identical strings have similarity 1.0', () {
      expect(
        TokenSortRatio.similarity('hello world', 'hello world'),
        equals(1.0),
      );
    });

    test('handles word order variations', () {
      expect(
        TokenSortRatio.similarity(
          'queen bohemian rhapsody',
          'bohemian rhapsody queen',
        ),
        equals(1.0),
      );
    });

    test('handles different word counts', () {
      final similarity = TokenSortRatio.similarity(
        'hello world',
        'hello world foo',
      );
      expect(similarity, lessThan(1.0));
      expect(similarity, greaterThan(0.0));
    });
  });

  group('Soundex', () {
    test('encodes to 4 characters', () {
      expect(Soundex.encode('Robert').length, equals(4));
      expect(Soundex.encode('Rupert').length, equals(4));
    });

    test('similar sounding names have same code', () {
      expect(Soundex.encode('Robert'), equals(Soundex.encode('Rupert')));
    });

    test('homophones have same code', () {
      expect(Soundex.encode('rhapsody'), equals(Soundex.encode('rapsody')));
    });

    test('different sounds have different codes', () {
      expect(Soundex.encode('hello'), isNot(equals(Soundex.encode('world'))));
    });

    test('isSimilar returns true for homophones', () {
      expect(Soundex.isSimilar('rhapsody', 'rapsody'), isTrue);
    });

    test('isSimilar returns false for different sounds', () {
      expect(Soundex.isSimilar('hello', 'world'), isFalse);
    });

    test('handles empty string', () {
      expect(Soundex.encode(''), equals(''));
      expect(Soundex.isSimilar('', 'hello'), isFalse);
    });
  });
}
