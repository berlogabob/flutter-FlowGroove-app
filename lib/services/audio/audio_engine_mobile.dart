// Mobile audio engine using audioplayers package
// For web, use audio_engine_web.dart

import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Audio engine for metronome sound synthesis
/// Mobile version using audioplayers with synthesized PCM audio
class AudioEngine {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  bool get initialized => _initialized;

  /// Audio sample rate for synthesized sounds
  static const int _sampleRate = 44100;

  /// Click duration in seconds (40ms like Reaper)
  static const double _clickDuration = 0.04;

  /// Initialize audio engine
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Pre-configure audio player for low-latency playback
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      _initialized = true;
      debugPrint('[AudioEngine] Mobile audio engine initialized');
    } catch (e) {
      debugPrint('[AudioEngine] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Play a click sound
  /// [isAccent] - true for accented beat (higher pitch)
  /// [waveType] - 'sine', 'square', 'triangle', or 'sawtooth'
  /// [volume] - 0.0 to 1.0
  /// [accentFrequency] - frequency for accented beat in Hz (default: 1600)
  /// [beatFrequency] - frequency for regular beat in Hz (default: 800)
  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Generate synthesized click sound
      final frequency = isAccent
          ? (accentFrequency ?? 1600.0)
          : (beatFrequency ?? 800.0);

      final pcmBytes = _generateClickSound(
        frequency: frequency,
        waveType: waveType,
        volume: volume.clamp(0.0, 1.0),
      );

      // Play the synthesized sound using BytesSource
      await _player.play(BytesSource(pcmBytes), volume: 1.0);

      debugPrint(
        '[AudioEngine] Played click: accent=$isAccent, freq=${frequency}Hz, wave=$waveType, vol=$volume',
      );
    } catch (e) {
      debugPrint('[AudioEngine] Error playing click: $e');
    }
  }

  /// Generate PCM audio data for a click sound as 16-bit WAV format
  Uint8List _generateClickSound({
    required double frequency,
    required String waveType,
    required double volume,
  }) {
    final numSamples = (_sampleRate * _clickDuration).toInt();

    // Generate float samples first
    final samples = _generateSamples(
      frequency: frequency,
      waveType: waveType,
      volume: volume,
      numSamples: numSamples,
    );

    // Convert to 16-bit PCM bytes
    return _floatToPcm16(samples);
  }

  /// Generate float audio samples
  Float32List _generateSamples({
    required double frequency,
    required String waveType,
    required double volume,
    required int numSamples,
  }) {
    final samples = Float32List(numSamples);

    // Wave function generator
    double Function(double phase) waveFunc;
    switch (waveType.toLowerCase()) {
      case 'square':
        waveFunc = (phase) => phase < 0.5 ? 1.0 : -1.0;
        break;
      case 'triangle':
        waveFunc = (phase) => 2.0 * (phase - 0.5).abs() * 2 - 1;
        break;
      case 'sawtooth':
        waveFunc = (phase) => 2.0 * phase - 1;
        break;
      case 'sine':
      default:
        waveFunc = (phase) => sin(2 * pi * phase);
        break;
    }

    // Generate samples with envelope to avoid clicking
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final phase = (frequency * t) % 1.0;

      // Apply envelope (attack and decay)
      final envelope = _calculateEnvelope(t, _clickDuration);

      samples[i] = waveFunc(phase) * volume * envelope;
    }

    return samples;
  }

  /// Convert float samples to 16-bit PCM bytes with WAV header
  Uint8List _floatToPcm16(Float32List samples) {
    final numSamples = samples.length;
    final byteData = ByteData(
      44 + numSamples * 2,
    ); // WAV header + 16-bit samples

    // Write WAV header
    // RIFF chunk
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + numSamples * 2, Endian.little); // File size - 8

    // WAVE format
    byteData.setUint8(8, 0x57); // 'W'
    byteData.setUint8(9, 0x41); // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    byteData.setUint16(22, 1, Endian.little); // NumChannels (1 for mono)
    byteData.setUint32(24, _sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, _sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little); // BlockAlign
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample (16)

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, numSamples * 2, Endian.little); // Subchunk2Size

    // Write samples as 16-bit PCM
    for (int i = 0; i < numSamples; i++) {
      // Clamp sample to [-1, 1] range
      final sample = samples[i].clamp(-1.0, 1.0);
      // Convert to 16-bit integer
      final intSample = (sample * 32767).toInt();
      byteData.setInt16(44 + i * 2, intSample, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  /// Calculate amplitude envelope for smooth click sound
  double _calculateEnvelope(double time, double duration) {
    const attackTime = 0.001; // 1ms attack
    const decayTime = 0.039; // 39ms decay

    if (time < attackTime) {
      // Attack phase: linear ramp up
      return time / attackTime;
    } else if (time < duration) {
      // Decay phase: exponential decay
      final decayProgress = (time - attackTime) / decayTime;
      return exp(-3.0 * decayProgress);
    }
    return 0.0;
  }

  /// Play test sound to verify audio works
  Future<void> playTest() async {
    debugPrint('[AudioEngine] Playing test sound...');

    // Play accented click
    await playClick(
      isAccent: true,
      waveType: 'sine',
      volume: 0.5,
      accentFrequency: 1600,
      beatFrequency: 800,
    );

    // Wait between clicks
    await Future.delayed(const Duration(milliseconds: 200));

    // Play regular click
    await playClick(
      isAccent: false,
      waveType: 'sine',
      volume: 0.5,
      accentFrequency: 1600,
      beatFrequency: 800,
    );

    debugPrint('[AudioEngine] Test sound complete');
  }

  /// Dispose audio resources
  void dispose() {
    try {
      _player.dispose();
      _initialized = false;
      debugPrint('[AudioEngine] Disposed');
    } catch (e) {
      debugPrint('[AudioEngine] Error during dispose: $e');
    }
  }
}
