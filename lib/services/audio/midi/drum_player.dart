import 'dart:async';
import 'dart:typed_data';

import '../../../models/midi_pattern.dart';
import 'drum_map.dart';

export 'drum_player_soloud.dart'
    if (dart.library.js_interop) 'drum_player_web.dart'
    show createDrumPlayer;

abstract class DrumPlayer {
  Future<void> load(MidiPattern p, double bpm);
  Future<void> start();
  Future<void> stop();
  void setLaneGain(DrumLane lane, double gain);
  bool get playing;
  Stream<int> get stepStream;
  Future<void> dispose();
}

/// Encodes mono samples as a little-endian, 16-bit PCM WAV.
Uint8List encodeDrumWav(Float32List samples, {int sampleRate = 44100}) {
  if (sampleRate <= 0) {
    throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
  }
  final bytes = Uint8List(44 + samples.length * 2);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final value = samples[i].clamp(-1.0, 1.0);
    final pcm = (value * (value < 0 ? 32768 : 32767)).round();
    data.setInt16(44 + i * 2, pcm, Endian.little);
  }
  return bytes;
}

int drumStepIndex(
  Duration elapsed,
  double bpm,
  int stepsPerBeat,
  int totalSteps,
) {
  if (!bpm.isFinite || bpm <= 0) {
    throw ArgumentError.value(bpm, 'bpm', 'Must be finite and positive');
  }
  if (stepsPerBeat <= 0 || totalSteps <= 0 || elapsed.isNegative) {
    throw ArgumentError('Step counts must be positive and elapsed nonnegative');
  }
  return (elapsed.inMicroseconds * bpm * stepsPerBeat / 60000000).floor() %
      totalSteps;
}

/// Polls wall time so a delayed timer skips directly to the current step.
class DrumStepClock {
  final _steps = StreamController<int>.broadcast();
  final _stopwatch = Stopwatch();
  Timer? _timer;

  Stream<int> get stream => _steps.stream;
  bool get playing => _stopwatch.isRunning;

  void start(MidiPattern p, double bpm) {
    stop();
    _stopwatch
      ..reset()
      ..start();
    var previous = 0;
    _steps.add(previous);
    _timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final step = drumStepIndex(
        _stopwatch.elapsed,
        bpm,
        p.stepsPerBeat,
        p.totalSteps,
      );
      if (step != previous) {
        previous = step;
        _steps.add(step);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
  }

  Future<void> dispose() async {
    stop();
    await _steps.close();
  }
}
