import 'dart:typed_data';

import 'package:flowgroove/services/audio/midi/drum_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodeDrumWav', () {
    test('writes a complete mono PCM header with the exact data length', () {
      final wav = encodeDrumWav(
        Float32List.fromList([0, 0.5, -0.5]),
        sampleRate: 48000,
      );
      final header = ByteData.sublistView(wav);

      expect(wav.length, 44 + 3 * 2);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(header.getUint32(4, Endian.little), wav.length - 8);
      expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
      expect(header.getUint32(16, Endian.little), 16);
      expect(header.getUint16(20, Endian.little), 1); // PCM
      expect(header.getUint16(22, Endian.little), 1); // Mono
      expect(header.getUint32(24, Endian.little), 48000);
      expect(header.getUint32(28, Endian.little), 96000); // Bytes/second
      expect(header.getUint16(32, Endian.little), 2); // Bytes/frame
      expect(header.getUint16(34, Endian.little), 16);
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      expect(header.getUint32(40, Endian.little), 6);
      expect(header.getInt16(44, Endian.little), 0);
      expect(header.getInt16(46, Endian.little), 16384);
      expect(header.getInt16(48, Endian.little), -16384);
    });

    test('clips summed samples to the signed 16-bit range', () {
      final wav = encodeDrumWav(Float32List.fromList([-2, -1, 0, 1, 2]));
      final data = ByteData.sublistView(wav);
      expect(
        List.generate(5, (i) => data.getInt16(44 + i * 2, Endian.little)),
        [-32768, -32768, 0, 32767, 32767],
      );
      expect(data.getUint32(24, Endian.little), 44100);
    });

    test('empty samples produce a valid empty WAV', () {
      final wav = encodeDrumWav(Float32List(0));
      final data = ByteData.sublistView(wav);
      expect(wav.length, 44);
      expect(data.getUint32(4, Endian.little), 36);
      expect(data.getUint32(40, Endian.little), 0);
    });

    test('rejects nonpositive sample rates', () {
      for (final rate in [0, -1]) {
        expect(
          () => encodeDrumWav(Float32List(1), sampleRate: rate),
          throwsArgumentError,
        );
      }
    });
  });

  group('drumStepIndex', () {
    test('advances at the exact sixteenth-note boundary at 120 BPM', () {
      expect(drumStepIndex(Duration.zero, 120, 4, 16), 0);
      expect(
        drumStepIndex(const Duration(microseconds: 124999), 120, 4, 16),
        0,
      );
      expect(drumStepIndex(const Duration(milliseconds: 125), 120, 4, 16), 1);
      expect(drumStepIndex(const Duration(milliseconds: 500), 120, 4, 16), 4);
      expect(drumStepIndex(const Duration(milliseconds: 1999), 120, 4, 16), 15);
    });

    test('wraps at the pattern length and skips missed steps', () {
      expect(drumStepIndex(const Duration(seconds: 2), 120, 4, 16), 0);
      expect(drumStepIndex(const Duration(milliseconds: 4625), 120, 4, 16), 5);
      expect(drumStepIndex(const Duration(milliseconds: 4625), 120, 4, 32), 5);
      expect(drumStepIndex(const Duration(seconds: 2), 120, 4, 32), 16);
    });

    test('uses the supplied tempo and subdivision', () {
      expect(drumStepIndex(const Duration(milliseconds: 250), 60, 4, 16), 1);
      expect(drumStepIndex(const Duration(milliseconds: 250), 120, 4, 16), 2);
      expect(drumStepIndex(const Duration(milliseconds: 250), 120, 8, 32), 4);
      expect(drumStepIndex(const Duration(seconds: 60), 121.5, 4, 32), 6);
      expect(drumStepIndex(const Duration(hours: 1), 121, 4, 16), 0);
    });

    test('rejects invalid tempo, step counts, and negative elapsed time', () {
      for (final bpm in [0.0, -120.0, double.nan, double.infinity]) {
        expect(
          () => drumStepIndex(Duration.zero, bpm, 4, 16),
          throwsArgumentError,
        );
      }
      expect(
        () => drumStepIndex(Duration.zero, 120, 0, 16),
        throwsArgumentError,
      );
      expect(
        () => drumStepIndex(Duration.zero, 120, 4, 0),
        throwsArgumentError,
      );
      expect(
        () => drumStepIndex(const Duration(microseconds: -1), 120, 4, 16),
        throwsArgumentError,
      );
    });
  });
}
