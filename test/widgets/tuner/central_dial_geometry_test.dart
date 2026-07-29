import 'dart:math' as math;

import 'package:flowgroove/widgets/tuner/central_dial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TunerDialGeometry', () {
    test('places note index i at the ruler angle -90° + i*30°', () {
      for (var i = 0; i < 12; i++) {
        expect(
          TunerDialGeometry.angleForNoteIndex(i),
          closeTo((-90 + i * 30) * math.pi / 180, 0.000001),
        );
      }
    });

    test(
      'handle rotation is the delta from north: exactly i*30° for index i',
      () {
        // Regression for the orange-dot bug: the edge handle is pre-translated
        // to 12 o'clock (where index 0 lives), so rotating it by the ABSOLUTE
        // ruler angle (-90° + i*30°) overshoots by a quarter turn and points
        // 3 semitones counter-clockwise of the selected note.
        for (var i = 0; i < 12; i++) {
          expect(
            TunerDialGeometry.rotationForNoteIndex(i),
            closeTo(i * 30 * math.pi / 180, 0.000001),
          );
        }
        // C (index 0): handle stays at north.
        expect(TunerDialGeometry.rotationForNoteIndex(0), closeTo(0, 1e-9));
        // A (index 9): 270° clockwise from north.
        expect(
          TunerDialGeometry.rotationForNoteIndex(9),
          closeTo(3 * math.pi / 2, 0.000001),
        );
      },
    );

    test('rotation for a frequency points at its nearest note', () {
      // 440 Hz at A4=440 is A (index 9).
      expect(
        TunerDialGeometry.rotationForFrequency(440, 440),
        closeTo(TunerDialGeometry.rotationForNoteIndex(9), 0.000001),
      );
      // 261.63 Hz is C4 (index 0) — handle at north.
      expect(
        TunerDialGeometry.rotationForFrequency(261.63, 440),
        closeTo(0, 0.000001),
      );
      // Slightly sharp/flat frequencies still snap to the nearest note.
      expect(
        TunerDialGeometry.rotationForFrequency(445, 440),
        closeTo(TunerDialGeometry.rotationForNoteIndex(9), 0.000001),
      );
    });

    test('angle -> frequency -> angle round trip is identity for all notes',
        () {
      for (final referenceA4 in <double>[415, 440, 442, 466]) {
        for (var i = 0; i < 12; i++) {
          final angle = TunerDialGeometry.angleForNoteIndex(i);
          final frequency = TunerDialGeometry.frequencyForAngle(
            angle,
            referenceA4,
          );
          expect(
            TunerDialGeometry.chromaticIndexForFrequency(
              frequency,
              referenceA4,
            ),
            i,
            reason: 'index $i at A4=$referenceA4',
          );
        }
      }
    });

    test('frequencyForAngle honours the A4 calibration', () {
      final aAngle = TunerDialGeometry.angleForNoteIndex(9); // A
      expect(TunerDialGeometry.frequencyForAngle(aAngle, 440), closeTo(440, 0.01));
      expect(TunerDialGeometry.frequencyForAngle(aAngle, 442), closeTo(442, 0.01));
      final cAngle = TunerDialGeometry.angleForNoteIndex(0); // C4
      expect(TunerDialGeometry.frequencyForAngle(cAngle, 440), closeTo(261.63, 0.01));
    });
  });
}
