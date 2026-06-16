import 'dart:math' as math;
import 'dart:typed_data';

/// Signal quality reported by the tuner analysis pipeline.
enum TunerSignalState { idle, noSignal, unstable, detected, inTune }

/// Result of analysing one mono PCM16 frame.
class PitchAnalysisResult {

  const PitchAnalysisResult({
    required this.frequencyHz,
    required this.confidence,
    required this.rmsDb,
  });

  factory PitchAnalysisResult.fromMap(Map<Object?, Object?> map) {
    return PitchAnalysisResult(
      frequencyHz: (map['frequencyHz'] as num?)?.toDouble(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      rmsDb: (map['rmsDb'] as num?)?.toDouble() ?? -120,
    );
  }
  final double? frequencyHz;
  final double confidence;
  final double rmsDb;

  bool get hasPitch => frequencyHz != null && frequencyHz! > 0;

  Map<String, Object?> toMap() => {
    'frequencyHz': frequencyHz,
    'confidence': confidence,
    'rmsDb': rmsDb,
  };
}

/// Musical-note conversion helpers using configurable equal temperament.
class TunerNoteMath {
  static const _noteNames = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static int midiForFrequency(double frequencyHz, double referenceHz) {
    return (69 + 12 * math.log(frequencyHz / referenceHz) / math.ln2).round();
  }

  static double frequencyForMidi(int midi, double referenceHz) {
    return referenceHz * math.pow(2, (midi - 69) / 12);
  }

  static String noteNameForMidi(int midi) {
    final note = _noteNames[((midi % 12) + 12) % 12];
    final octave = (midi ~/ 12) - 1;
    return '$note$octave';
  }

  static double centsFromNearestNote(double frequencyHz, double referenceHz) {
    final exactMidi = 69 + 12 * math.log(frequencyHz / referenceHz) / math.ln2;
    return (exactMidi - exactMidi.round()) * 100;
  }

  static double frequencyForNote(String noteName, double referenceHz) {
    final match = RegExp(r'^([A-Ga-g])([#b]?)(-?\d+)$').firstMatch(noteName);
    if (match == null) {
      throw FormatException('Invalid note name: $noteName');
    }

    const naturalOffsets = <String, int>{
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    final natural = match.group(1)!.toUpperCase();
    final accidental = match.group(2)!;
    final octave = int.parse(match.group(3)!);
    var semitone = naturalOffsets[natural]!;
    if (accidental == '#') semitone++;
    if (accidental == 'b') semitone--;
    final midi = (octave + 1) * 12 + semitone;
    return frequencyForMidi(midi, referenceHz);
  }
}

/// Top-level entry point used by Flutter's background [compute] helper.
Map<String, Object?> analysePitchFrame(Map<String, Object?> request) {
  final bytes = request['bytes']! as Uint8List;
  final sampleRate = (request['sampleRate']! as num).toDouble();
  final noiseFloorDb = (request['noiseFloorDb']! as num).toDouble();
  final minFrequency = (request['minFrequency']! as num).toDouble();
  final maxFrequency = (request['maxFrequency']! as num).toDouble();

  final samples = _pcm16ToSamples(bytes);
  final rmsDb = _rmsDb(samples);
  if (samples.length < 512 || rmsDb < noiseFloorDb) {
    return PitchAnalysisResult(
      frequencyHz: null,
      confidence: 0,
      rmsDb: rmsDb,
    ).toMap();
  }

  final result = _yin(
    samples,
    sampleRate: sampleRate,
    minFrequency: minFrequency,
    maxFrequency: maxFrequency,
  );
  return PitchAnalysisResult(
    frequencyHz: result.$1,
    confidence: result.$2,
    rmsDb: rmsDb,
  ).toMap();
}

Float64List _pcm16ToSamples(Uint8List bytes) {
  final sampleCount = bytes.length ~/ 2;
  final result = Float64List(sampleCount);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < sampleCount; index++) {
    result[index] = data.getInt16(index * 2, Endian.little) / 32768.0;
  }
  return result;
}

double _rmsDb(Float64List samples) {
  var sum = 0.0;
  for (final sample in samples) {
    sum += sample * sample;
  }
  final rms = math.sqrt(sum / samples.length);
  if (rms <= 0.000001) return -120;
  return 20 * math.log(rms) / math.ln10;
}

(double?, double) _yin(
  Float64List samples, {
  required double sampleRate,
  required double minFrequency,
  required double maxFrequency,
}) {
  final minTau = math.max(2, (sampleRate / maxFrequency).floor());
  final maxTau = math.min(
    samples.length ~/ 2,
    (sampleRate / minFrequency).ceil(),
  );
  if (maxTau <= minTau) return (null, 0);

  final difference = Float64List(maxTau + 1);
  for (var tau = minTau; tau <= maxTau; tau++) {
    var sum = 0.0;
    final limit = samples.length - tau;
    for (var index = 0; index < limit; index++) {
      final delta = samples[index] - samples[index + tau];
      sum += delta * delta;
    }
    difference[tau] = sum;
  }

  final normalized = Float64List(maxTau + 1);
  var runningSum = 0.0;
  normalized[0] = 1;
  for (var tau = 1; tau <= maxTau; tau++) {
    runningSum += difference[tau];
    normalized[tau] = runningSum == 0 ? 1 : difference[tau] * tau / runningSum;
  }

  const threshold = 0.15;
  var selectedTau = -1;
  for (var tau = minTau; tau < maxTau; tau++) {
    if (normalized[tau] < threshold) {
      while (tau + 1 <= maxTau && normalized[tau + 1] < normalized[tau]) {
        tau++;
      }
      selectedTau = tau;
      break;
    }
  }

  if (selectedTau < 0) {
    var bestValue = double.infinity;
    for (var tau = minTau; tau <= maxTau; tau++) {
      if (normalized[tau] < bestValue) {
        bestValue = normalized[tau];
        selectedTau = tau;
      }
    }
    if (bestValue > 0.35) return (null, 1 - bestValue.clamp(0.0, 1.0));
  }

  final refinedTau = _parabolicTau(normalized, selectedTau, maxTau);
  final frequency = sampleRate / refinedTau;
  final confidence = 1 - normalized[selectedTau].clamp(0.0, 1.0);
  if (frequency < minFrequency || frequency > maxFrequency) {
    return (null, confidence);
  }
  return (frequency, confidence);
}

double _parabolicTau(Float64List values, int tau, int maxTau) {
  if (tau <= 1 || tau >= maxTau) return tau.toDouble();
  final left = values[tau - 1];
  final center = values[tau];
  final right = values[tau + 1];
  final denominator = 2 * (2 * center - right - left);
  if (denominator.abs() < 0.0000001) return tau.toDouble();
  return tau + (right - left) / denominator;
}
