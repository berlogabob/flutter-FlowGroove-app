import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Tone generator service for tuner generate mode.
///
/// Uses the current SoLoud audio stack. Do not deinitialize SoLoud from here:
/// the metronome engine may be sharing the same global audio backend.
class ToneGenerator {
  AudioSource? _source;
  SoundHandle? _handle;
  bool _isPlaying = false;
  double _currentVolume = 0.5;
  double? _currentFrequency;

  static const int _sampleRate = 44100;
  static const double _toneDuration = 1.0;

  Future<void> _ensureInitialized() async {
    if (SoLoud.instance.isInitialized) return;

    await SoLoud.instance.init(
      bufferSize: 512,
      channels: Channels.mono,
      sampleRate: _sampleRate,
    );
  }

  /// Start playing a sine wave tone at the specified frequency.
  Future<void> startTone(double frequency, double volume) async {
    if (_isPlaying && _currentFrequency == frequency) return;

    await stopTone();
    await _ensureInitialized();

    _currentVolume = volume.clamp(0.0, 1.0);
    _currentFrequency = frequency;

    final wavBytes = _generateWavBytes(frequency, duration: _toneDuration);
    _source = await SoLoud.instance.loadMem(
      'tuner_${frequency.toStringAsFixed(2)}_${DateTime.now().microsecondsSinceEpoch}.wav',
      wavBytes,
    );
    _handle = await SoLoud.instance.play(
      _source!,
      volume: _currentVolume,
      looping: true,
    );
    _isPlaying = true;
  }

  /// Stop playing the tone and release only this generator's source.
  Future<void> stopTone() async {
    final handle = _handle;
    _handle = null;

    if (handle != null && SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.stop(handle);
      } catch (error) {
        debugPrint('Error stopping tone handle: $error');
      }
    }

    await _disposeSource();
    _isPlaying = false;
    _currentFrequency = null;
  }

  /// Update volume while playing.
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    final handle = _handle;
    if (handle != null && SoLoud.instance.isInitialized) {
      SoLoud.instance.setVolume(handle, _currentVolume);
    }
  }

  /// Update frequency while playing.
  Future<void> setFrequency(double frequency) async {
    if (!_isPlaying) {
      _currentFrequency = frequency;
      return;
    }
    await startTone(frequency, _currentVolume);
  }

  /// Check if currently playing.
  bool get isPlaying => _isPlaying;

  /// Dispose of resources owned by this tone generator.
  Future<void> dispose() async {
    await stopTone();
  }

  Future<void> _disposeSource() async {
    final source = _source;
    _source = null;
    if (source != null && SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.disposeSource(source);
      } catch (error) {
        debugPrint('Error disposing tone source: $error');
      }
    }
  }

  /// Generate WAV bytes for a sine wave tone.
  Uint8List _generateWavBytes(double frequency, {required double duration}) {
    const channels = 1;
    const bitsPerSample = 16;

    final numSamples = (_sampleRate * duration).round();
    final bytesPerSample = bitsPerSample ~/ 8;
    final byteRate = _sampleRate * channels * bytesPerSample;
    final blockSize = channels * bytesPerSample;
    final dataSize = numSamples * channels * bytesPerSample;
    final fileSize = 36 + dataSize;
    final bytes = BytesBuilder(copy: false);

    bytes.add('RIFF'.codeUnits);
    bytes.add(_intToLittleEndian(fileSize, 4));
    bytes.add('WAVE'.codeUnits);
    bytes.add('fmt '.codeUnits);
    bytes.add(_intToLittleEndian(16, 4));
    bytes.add(_intToLittleEndian(1, 2));
    bytes.add(_intToLittleEndian(channels, 2));
    bytes.add(_intToLittleEndian(_sampleRate, 4));
    bytes.add(_intToLittleEndian(byteRate, 4));
    bytes.add(_intToLittleEndian(blockSize, 2));
    bytes.add(_intToLittleEndian(bitsPerSample, 2));
    bytes.add('data'.codeUnits);
    bytes.add(_intToLittleEndian(dataSize, 4));

    final attackSamples = (_sampleRate * 0.01).round();
    final releaseSamples = (_sampleRate * 0.05).round();

    for (var i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final wave = math.sin(2 * math.pi * frequency * t);

      double envelope;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i >= numSamples - releaseSamples) {
        envelope = (numSamples - i) / releaseSamples;
      } else {
        envelope = 1.0;
      }

      final sample = wave * envelope;
      final pcmSample = (sample * 32767).clamp(-32768, 32767).toInt();
      bytes.add(<int>[pcmSample & 0xFF, (pcmSample >> 8) & 0xFF]);
    }

    return bytes.toBytes();
  }

  List<int> _intToLittleEndian(int value, int bytes) {
    final result = <int>[];
    var currentValue = value;
    for (var i = 0; i < bytes; i++) {
      result.add(currentValue & 0xFF);
      currentValue >>= 8;
    }
    return result;
  }
}
