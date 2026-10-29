import 'package:flowgroove/services/audio/midi/gm_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gmProgramName', () {
    test('has 128 entries', () {
      expect(gmProgramNames.length, 128);
    });

    test('returns the name for valid programs', () {
      expect(gmProgramName(0), 'Acoustic Grand Piano');
      expect(gmProgramName(33), 'Electric Bass (finger)');
      expect(gmProgramName(24), 'Acoustic Guitar (nylon)');
    });

    test('returns Instrument for out-of-range programs', () {
      expect(gmProgramName(-1), 'Instrument');
      expect(gmProgramName(128), 'Instrument');
    });
  });
}
