import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_samples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const durations = <DrumLane, double>{
    DrumLane.kick: 0.3,
    DrumLane.snare: 0.2,
    DrumLane.hatClosed: 0.06,
    DrumLane.hatOpen: 0.35,
    DrumLane.tomHigh: 0.3,
    DrumLane.tomMid: 0.3,
    DrumLane.tomFloor: 0.3,
    DrumLane.crash: 1.2,
    DrumLane.ride: 0.8,
  };

  for (final lane in DrumLane.values) {
    test('${lane.name} defaults to 44100 Hz', () {
      expect(drumSample(lane).length, (durations[lane]! * 44100).round());
    });

    for (final sampleRate in [22050, 44100, 48000]) {
      test(
        '${lane.name} has a normalized, decaying tail at $sampleRate Hz',
        () {
          final sample = drumSample(lane, sampleRate: sampleRate);
          expect(sample, isNotEmpty);
          expect(sample.length, (durations[lane]! * sampleRate).round());
          expect(sample.every((value) => value.isFinite), isTrue);
          final peak = sample.map((value) => value.abs()).reduce(math.max);
          expect(peak, lessThanOrEqualTo(0.9));
          expect(peak, closeTo(0.9, 1e-6));
          expect(sample.last, closeTo(0, 1e-9));

          final quarter = sample.length ~/ 4;
          final attackEnergy = sample
              .take(quarter)
              .fold<double>(0, (sum, v) => sum + v * v);
          final tailEnergy = sample
              .skip(sample.length - quarter)
              .fold<double>(0, (sum, v) => sum + v * v);
          expect(tailEnergy, lessThan(attackEnergy * 0.01));
        },
      );
    }

    test('${lane.name} is deterministic and returns independent buffers', () {
      final first = drumSample(lane);
      drumSample(DrumLane.crash);
      final second = drumSample(lane);
      expect(first, orderedEquals(second));
      first[0] = 10;
      expect(drumSample(lane), orderedEquals(second));
    });
  }

  test('tom pitches descend from high to floor', () {
    int crossings(DrumLane lane) {
      final sample = drumSample(lane);
      var count = 0;
      for (var i = 1; i < sample.length; i++) {
        if (sample[i - 1] <= 0 && sample[i] > 0) count++;
      }
      return count;
    }

    expect(
      crossings(DrumLane.tomHigh),
      greaterThan(crossings(DrumLane.tomMid)),
    );
    expect(
      crossings(DrumLane.tomMid),
      greaterThan(crossings(DrumLane.tomFloor)),
    );
  });

  test('rejects non-positive sample rates', () {
    for (final sampleRate in [0, -44100]) {
      expect(
        () => drumSample(DrumLane.kick, sampleRate: sampleRate),
        throwsArgumentError,
      );
    }
  });
  realSamplesTests();
}

void realSamplesTests() {
  test('decodeWavMono16 rejects non-wav and wrong formats', () {
    expect(decodeWavMono16(Uint8List.fromList([1, 2, 3])), isNull);
    expect(decodeWavMono16(Uint8List(60)), isNull);
  });

  test(
    'every lane has a recorded asset that decodes and beats the synth length',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final synth = {for (final l in DrumLane.values) l: drumSample(l)};
      await preloadDrumSamples();
      for (final lane in DrumLane.values) {
        final real = drumSample(lane);
        expect(
          real,
          isNot(same(synth[lane])),
          reason: '${lane.name} not recorded',
        );
        expect(real.length, greaterThan(1000), reason: lane.name);
        final peak = real.fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
        expect(peak, inInclusiveRange(0.5, 1.0), reason: lane.name);
      }
    },
  );
}
