import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

/// Records via `record`'s PCM16 stream and wraps the result into a WAV
/// container on stop.
///
/// This is the web capture path for audio memos (#150): the PCM stream is the
/// same proven route the tuner uses on web, and WAV sidesteps MediaRecorder
/// codec/Safari-playback risk entirely — every platform plays it.
/// ponytail: WAV costs ~5.3MB/min mono; callers cap duration (Storage rejects
/// >=25MB). Switch to opus/webm if longer memos ever matter.
class PcmWavRecorder {
  PcmWavRecorder(this._recorder);

  final AudioRecorder _recorder;
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _sub;
  int _sampleRate = 44100;

  /// Called with the level of each incoming chunk in dBFS (~-90..0).
  void Function(double dbfs)? onLevel;

  bool get isRecording => _sub != null;

  Future<void> start() async {
    if (_sub != null) return;
    _pcm.clear();
    _sampleRate = 44100;
    await _recorder.setOnConfigChanged((config) {
      _sampleRate = config.sampleRate;
    });
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        streamBufferSize: 4096,
      ),
    );
    _sub = stream.listen((chunk) {
      _pcm.add(chunk);
      onLevel?.call(_rmsDbfs(chunk));
    });
  }

  /// Stops capture and returns the recording as WAV bytes.
  Future<Uint8List> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    return wavFromPcm16(_pcm.takeBytes(), sampleRate: _sampleRate);
  }

  Future<void> cancel() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    _pcm.clear();
  }

  static double _rmsDbfs(Uint8List chunk) {
    final data = ByteData.sublistView(chunk);
    final samples = chunk.length ~/ 2;
    if (samples == 0) return -90;
    var sum = 0.0;
    for (var offset = 0; offset + 1 < chunk.length; offset += 2) {
      final v = data.getInt16(offset, Endian.little) / 32768.0;
      sum += v * v;
    }
    final rms = math.sqrt(sum / samples);
    if (rms <= 0.00003) return -90;
    return 20 * math.log(rms) / math.ln10;
  }
}

/// Wraps raw little-endian PCM16 in a standard 44-byte RIFF/WAVE header.
Uint8List wavFromPcm16(
  Uint8List pcm, {
  required int sampleRate,
  int channels = 1,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final header = ByteData(44);

  void writeAscii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  header.setUint16(20, 1, Endian.little); // PCM format
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  final out = Uint8List(44 + pcm.length)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + pcm.length, pcm);
  return out;
}
