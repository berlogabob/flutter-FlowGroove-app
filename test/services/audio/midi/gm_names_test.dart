import 'package:flowgroove/services/audio/midi/gm_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gmNames', () {
    test('has 128 entries', () {
      expect(gmNames.length, 128);
    });

    test('known program numbers', () {
      expect(gmNames[0], 'Acoustic Grand Piano');
      expect(gmNames[24], 'Acoustic Guitar (nylon)');
      expect(gmNames[33], 'Electric Bass (finger)');
    });
  });

  group('gmProgramName', () {
    test('returns the name for valid programs', () {
      expect(gmProgramName(0), 'Acoustic Grand Piano');
      expect(gmProgramName(24), 'Acoustic Guitar (nylon)');
      expect(gmProgramName(33), 'Electric Bass (finger)');
    });

    test('returns Instrument for out-of-range programs', () {
      expect(gmProgramName(-1), 'Instrument');
      expect(gmProgramName(128), 'Instrument');
    });
  });
}
