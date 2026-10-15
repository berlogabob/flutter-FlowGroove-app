import 'dart:math' as math;
import 'dart:typed_data';

import 'drum_map.dart';

Float32List drumSample(DrumLane lane, {int sampleRate = 44100}) {
  if (sampleRate <= 0) {
    throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
  }

  final duration = switch (lane) {
    DrumLane.kick ||
    DrumLane.tomHigh ||
    DrumLane.tomMid ||
    DrumLane.tomFloor => 0.3,
    DrumLane.snare => 0.2,
    DrumLane.hatClosed => 0.06,
    DrumLane.hatOpen => 0.35,
    DrumLane.crash => 1.2,
    DrumLane.ride => 0.8,
  };
  final samples = Float32List(math.max(2, (duration * sampleRate).round()));
  final random = math.Random(42 + lane.index);
  final highPass = math.exp(-2 * math.pi * 4000 / sampleRate);
  var previousNoise = 0.0;
  var filteredNoise = 0.0;
  var peak = 0.0;

  for (var i = 0; i < samples.length - 1; i++) {
    final t = i / sampleRate;
    final progress = i / (samples.length - 1);
    final envelope = math.exp(-6 * progress) * (1 - progress);
    double value;
    switch (lane) {
      case DrumLane.kick:
        // Integrating the frequency sweep preserves a continuous phase.
        final phase = 50 * t + 100 * (1 - math.exp(-30 * t)) / 30;
        value = math.sin(2 * math.pi * phase);
      case DrumLane.snare:
        value =
            0.8 * (random.nextDouble() * 2 - 1) +
            0.2 * math.sin(2 * math.pi * 190 * t);
      case DrumLane.hatClosed:
      case DrumLane.hatOpen:
        final noise = random.nextDouble() * 2 - 1;
        filteredNoise = highPass * (filteredNoise + noise - previousNoise);
        previousNoise = noise;
        value = filteredNoise;
      case DrumLane.tomHigh:
      case DrumLane.tomMid:
      case DrumLane.tomFloor:
        final pitch = switch (lane) {
          DrumLane.tomHigh => 180.0,
          DrumLane.tomMid => 135.0,
          _ => 90.0,
        };
        final phase = pitch * (t + (1 - math.exp(-20 * t)) / 20);
        value = math.sin(2 * math.pi * phase);
      case DrumLane.crash:
        value = random.nextDouble() * 2 - 1;
      case DrumLane.ride:
        value =
            math.sin(2 * math.pi * 620 * t) +
            0.7 * math.sin(2 * math.pi * 997 * t) +
            0.5 * math.sin(2 * math.pi * 1453 * t) +
            0.3 * math.sin(2 * math.pi * 2129 * t);
    }
    samples[i] = value * envelope;
    peak = math.max(peak, samples[i].abs());
  }

  if (peak > 0) {
    final gain = 0.9 / peak;
    for (var i = 0; i < samples.length - 1; i++) {
      samples[i] *= gain;
    }
  }
  return samples;
}
