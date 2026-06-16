/// Metronome sample generator
///
/// Generates PCM audio samples for metronome clicks with customizable
/// frequencies and wave types. Caches generated samples for instant playback.
///
/// Features:
/// - 6 base samples (3 beat types × 2 accent states)
/// - 4 wave types (sine, square, triangle, sawtooth)
/// - User custom frequencies cached on-demand
/// - Zero runtime synthesis (all pre-generated)
library;

import 'dart:math';
import 'dart:typed_data';
import '../../models/metronome_tone_config.dart';

/// Generates and caches metronome click samples
class MetronomeSampleGenerator {
  final Map<String, Uint8List> _sampleCache = {};
  static const int _sampleRate = 44100;
  static const double _clickDuration = 0.04; // 40ms

  /// Generate all 6 base samples from tone config
  Future<void> generateAllSamples(MetronomeToneConfig config) async {
    // Main beat samples
    _sampleCache['main_regular'] = await _generateSample(
      frequency: config.mainRegularFreq,
      waveType: config.waveType,
      volume: config.volume,
    );

    _sampleCache['main_accent'] = await _generateSample(
      frequency: config.mainAccentFreq,
      waveType: config.waveType,
      volume: config.volume,
    );

    // Sub beat samples
    _sampleCache['sub_regular'] = await _generateSample(
      frequency: config.subRegularFreq,
      waveType: config.waveType,
      volume: config.volume,
    );

    _sampleCache['sub_accent'] = await _generateSample(
      frequency: config.subAccentFreq,
      waveType: config.waveType,
      volume: config.volume,
    );

    // Divider samples
    _sampleCache['divider_regular'] = await _generateSample(
      frequency: config.dividerRegularFreq,
      waveType: config.waveType,
      volume: config.volume,
    );

    _sampleCache['divider_accent'] = await _generateSample(
      frequency: config.dividerAccentFreq,
      waveType: config.waveType,
      volume: config.volume,
    );
  }

  /// Get cached sample by key
  Uint8List getSample(String key) {
    return _sampleCache[key] ?? _sampleCache['main_regular']!;
  }

  /// Generate custom frequency sample (cached on first use)
  Future<Uint8List> getCustomSample({
    required double frequency,
    required String waveType,
    required double volume,
  }) async {
    final key = '${frequency}_$waveType';

    if (!_sampleCache.containsKey(key)) {
      _sampleCache[key] = await _generateSample(
        frequency: frequency,
        waveType: waveType,
        volume: volume,
      );
    }

    return _sampleCache[key]!;
  }

  /// Clear all cached samples
  void clearCache() {
    _sampleCache.clear();
  }

  /// Get cache size in bytes
  int get cacheSize => _sampleCache.values.fold(0, (sum, bytes) => sum + bytes.length);

  /// Generate single sample with specified parameters
  Future<Uint8List> _generateSample({
    required double frequency,
    required String waveType,
    required double volume,
  }) async {
    final numSamples = (_sampleRate * _clickDuration).round();
    final samples = Float32List(numSamples);

    // Generate waveform
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final envelope = _calculateEnvelope(t);
      samples[i] = _generateWave(t, frequency, waveType) * envelope * volume;
    }

    // Convert to 16-bit PCM with WAV header
    return _floatToPcm16(samples);
  }

  /// Calculate amplitude envelope (attack + decay)
  double _calculateEnvelope(double t) {
    const attackTime = 0.001; // 1ms attack
    const decayTime = 0.039; // 39ms decay

    if (t < attackTime) {
      // Linear attack
      return t / attackTime;
    } else if (t < attackTime + decayTime) {
      // Exponential decay
      final decayT = t - attackTime;
      return exp(-3.0 * decayT / decayTime);
    } else {
      return 0;
    }
  }

  /// Generate waveform sample
  double _generateWave(double t, double frequency, String waveType) {
    final phase = 2.0 * pi * frequency * t;

    switch (waveType.toLowerCase()) {
      case 'square':
        return sin(phase) >= 0 ? 1.0 : -1.0;

      case 'triangle':
        return 2.0 * (2.0 * (phase / (2.0 * pi) - (phase / (2.0 * pi)).floor()).abs() - 1.0) *
            (sin(phase) >= 0 ? 1.0 : -1.0);

      case 'sawtooth':
        return 2.0 * ((phase / (2.0 * pi)).floor() + 0.5 - (phase / (2.0 * pi)));

      case 'sine':
      default:
        return sin(phase);
    }
  }

  /// Convert float samples to 16-bit PCM with WAV header
  Uint8List _floatToPcm16(Float32List samples) {
    final numSamples = samples.length;
    final bytes = Uint8List(44 + numSamples * 2); // WAV header + data
    final view = ByteData.view(bytes.buffer);

    // WAV header (44 bytes)
    // RIFF chunk
    view.setUint8(0, 0x52); // 'R'
    view.setUint8(1, 0x49); // 'I'
    view.setUint8(2, 0x46); // 'F'
    view.setUint8(3, 0x46); // 'F'
    view.setUint32(4, 36 + numSamples * 2, Endian.little); // Chunk size

    // WAVE format
    view.setUint8(8, 0x57); // 'W'
    view.setUint8(9, 0x41); // 'A'
    view.setUint8(10, 0x56); // 'V'
    view.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    view.setUint8(12, 0x66); // 'f'
    view.setUint8(13, 0x6D); // 'm'
    view.setUint8(14, 0x74); // 't'
    view.setUint8(15, 0x20); // ' '
    view.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    view.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    view.setUint16(22, 1, Endian.little); // NumChannels (1 for mono)
    view.setUint32(24, _sampleRate, Endian.little); // SampleRate
    view.setUint32(28, _sampleRate * 2, Endian.little); // ByteRate
    view.setUint16(32, 2, Endian.little); // BlockAlign
    view.setUint16(34, 16, Endian.little); // BitsPerSample

    // data subchunk
    view.setUint8(36, 0x64); // 'd'
    view.setUint8(37, 0x61); // 'a'
    view.setUint8(38, 0x74); // 't'
    view.setUint8(39, 0x61); // 'a'
    view.setUint32(40, numSamples * 2, Endian.little); // Subchunk2Size

    // Audio data
    for (int i = 0; i < numSamples; i++) {
      final sample = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      view.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes;
  }
}
