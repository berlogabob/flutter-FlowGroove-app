import 'package:flowgroove/utils/key_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalKey', () {
    test('flats map to canonical sharps', () {
      expect(canonicalKey('Ab'), 'G#');
      expect(canonicalKey('Bb'), 'A#');
      expect(canonicalKey('Db'), 'C#');
      expect(canonicalKey('Eb'), 'D#');
      expect(canonicalKey('Gb'), 'F#');
    });

    test('is case-insensitive', () {
      expect(canonicalKey('ab'), canonicalKey('Ab'));
      expect(canonicalKey('c'), canonicalKey('C'));
    });

    test('minor flats and mixed case all normalize the same way', () {
      expect(canonicalKey('abm'), 'G#m');
      expect(canonicalKey('Abm'), 'G#m');
      expect(canonicalKey('ABM'), 'G#m');
      expect(canonicalKey('abm'), canonicalKey('Abm'));
      expect(canonicalKey('abm'), canonicalKey('G#m'));
    });

    test('lowercase-root minor form matches the Cm chip', () {
      expect(canonicalKey('cm'), 'Cm');
      expect(canonicalKey('cm'), canonicalKey('Cm'));
    });

    test('major and minor of the same root are distinct', () {
      expect(canonicalKey('C'), isNot(equals(canonicalKey('Cm'))));
      expect(canonicalKey('C'), 'C');
      expect(canonicalKey('Cm'), 'Cm');
    });

    test('null and empty input return null', () {
      expect(canonicalKey(null), isNull);
      expect(canonicalKey(''), isNull);
      expect(canonicalKey('   '), isNull);
    });

    test('unparseable input returns null', () {
      expect(canonicalKey('H'), isNull);
      expect(canonicalKey('Cx'), isNull);
    });
  });

  group('keyMatchesFilter', () {
    test('no filter matches everything', () {
      expect(keyMatchesFilter('Ab', null), isTrue);
      expect(keyMatchesFilter(null, null), isTrue);
      expect(keyMatchesFilter(null, ''), isTrue);
    });

    test('a song with no key never matches a specific key filter', () {
      expect(keyMatchesFilter(null, 'G#'), isFalse);
      expect(keyMatchesFilter('', 'G#'), isFalse);
    });

    test('flat/sharp enharmonic equivalents match', () {
      expect(keyMatchesFilter('Ab', 'G#'), isTrue);
      expect(keyMatchesFilter('G#', 'Ab'), isTrue);
    });

    test('minor forms match regardless of casing/spelling', () {
      expect(keyMatchesFilter('abm', 'G#m'), isTrue);
      expect(keyMatchesFilter('Abm', 'G#m'), isTrue);
      expect(keyMatchesFilter('cm', 'Cm'), isTrue);
    });

    test('major does not match minor of the same root', () {
      expect(keyMatchesFilter('C', 'Cm'), isFalse);
      expect(keyMatchesFilter('Cm', 'C'), isFalse);
    });

    test('different roots do not match', () {
      expect(keyMatchesFilter('C', 'D'), isFalse);
    });
  });
}
