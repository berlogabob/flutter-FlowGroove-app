import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flowgroove/services/audio/pitch_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pitch analysis', () {
    for (final frequency in <double>[
      41.2034,
      82.4069,
      261.6256,
      440,
      659.2551,
    ]) {
      test('detects ${frequency.toStringAsFixed(2)} Hz within one cent', () {
        final result = PitchAnalysisResult.fromMap(
          analysePitchFrame(<String, Object?>{
            'bytes': _sineWave(frequency, sampleRate: 44100),
            'sampleRate': 44100.0,
            'noiseFloorDb': -70.0,
            'minFrequency': 35.0,
            'maxFrequency': 2100.0,
          }),
        );

        expect(result.frequencyHz, isNotNull);
        expect(
          _centsBetween(result.frequencyHz!, frequency).abs(),
          lessThan(1),
        );
        expect(result.confidence, greaterThan(0.8));
      });
    }

    test('uses the effective sample rate', () {
      const frequency = 440.0;
      final result = PitchAnalysisResult.fromMap(
        analysePitchFrame(<String, Object?>{
          'bytes': _sineWave(frequency, sampleRate: 48000),
          'sampleRate': 48000.0,
          'noiseFloorDb': -70.0,
          'minFrequency': 35.0,
          'maxFrequency': 2100.0,
        }),
      );

      expect(_centsBetween(result.frequencyHz!, frequency).abs(), lessThan(1));
    });

    test('rejects silence below the noise floor', () {
      final result = PitchAnalysisResult.fromMap(
        analysePitchFrame(<String, Object?>{
          'bytes': Uint8List(4096 * 2),
          'sampleRate': 44100.0,
          'noiseFloorDb': -60.0,
          'minFrequency': 35.0,
          'maxFrequency': 2100.0,
        }),
      );

      expect(result.frequencyHz, isNull);
      expect(result.rmsDb, lessThan(-100));
    });
  });

  group('note math', () {
    test('uses base-2 pitch conversion', () {
      expect(TunerNoteMath.midiForFrequency(440, 440), 69);
      expect(TunerNoteMath.midiForFrequency(880, 440), 81);
      expect(TunerNoteMath.centsFromNearestNote(440, 440), closeTo(0, 0.001));
    });

    test('parses sharps and flats', () {
      final sharp = TunerNoteMath.frequencyForNote('D#4', 440);
      final flat = TunerNoteMath.frequencyForNote('Eb4', 440);
      expect(flat, closeTo(sharp, 0.0001));
    });
  });
}

Uint8List _sineWave(double frequency, {required int sampleRate}) {
  const sampleCount = 4096;
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < sampleCount; index++) {
    final value = math.sin(2 * math.pi * frequency * index / sampleRate);
    data.setInt16(index * 2, (value * 28000).round(), Endian.little);
  }
  return bytes;
}

double _centsBetween(double actual, double expected) {
  return 1200 * math.log(actual / expected) / math.ln2;
}
