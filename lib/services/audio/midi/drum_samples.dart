import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'drum_map.dart';

/// Real recorded hits (assets/sounds/drums/<lane>.wav, see LICENSE.txt there).
/// Filled by [preloadDrumSamples]; [drumSample] falls back to the synthesized
/// sound for any lane that is not loaded, so a missing asset never mutes drums.
final Map<DrumLane, Float32List> _recorded = {};
Future<void>? _preloading;

/// Loads the recorded samples once. Safe to call repeatedly and never throws.
Future<void> preloadDrumSamples() => _preloading ??= _preload();

Future<void> _preload() async {
  for (final lane in DrumLane.values) {
    try {
      final data = await rootBundle.load(
        'assets/sounds/drums/${lane.name}.wav',
      );
      final decoded = decodeWavMono16(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      if (decoded != null) _recorded[lane] = decoded;
    } on Object {
      // Missing/corrupt asset: keep the synthesized fallback for this lane.
    }
  }
}

/// Decodes a 16-bit PCM mono 44.1 kHz WAV into floats, or null if it is not one.
Float32List? decodeWavMono16(Uint8List bytes) {
  if (bytes.length < 44) return null;
  final view = ByteData.sublistView(bytes);
  String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  var pos = 12;
  var channels = 0;
  var bits = 0;
  var rate = 0;
  while (pos + 8 <= bytes.length) {
    final id = tag(pos);
    final size = view.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ' && body + 16 <= bytes.length) {
      channels = view.getUint16(body + 2, Endian.little);
      rate = view.getUint32(body + 4, Endian.little);
      bits = view.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (channels != 1 || bits != 16 || rate != 44100) return null;
      final count = (size.clamp(0, bytes.length - body)) ~/ 2;
      final out = Float32List(count);
      for (var i = 0; i < count; i++) {
        out[i] = view.getInt16(body + i * 2, Endian.little) / 32768.0;
      }
      return out;
    }
    pos = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

Float32List drumSample(DrumLane lane, {int sampleRate = 44100}) {
  if (sampleRate <= 0) {
    throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
  }
  final recorded = _recorded[lane];
  if (recorded != null && sampleRate == 44100) return recorded;

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
