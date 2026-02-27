import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Tone Generator service for producing sine wave tones
///
/// Uses audioplayers to generate pure sine wave tones
/// with smooth attack/release envelopes to prevent clicks.
///
/// Note: For Stage 2, we generate tones programmatically.
/// Stage 3 will implement more advanced audio synthesis.
class ToneGenerator {
  AudioPlayer? _player;
  bool _isInitialized = false;
  double _currentVolume = 0.5;
  bool _isPlaying = false;

  /// Initialize the audio player
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      _player = AudioPlayer();

      // Set up player for low-latency playback
      if (_player != null) {
        await _player!.setReleaseMode(ReleaseMode.stop);
        await _player!.setVolume(_currentVolume);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing tone generator: $e');
      rethrow;
    }
  }

  /// Start playing a sine wave tone at the specified frequency
  ///
  /// [frequency] - Frequency in Hz (20-2000 Hz recommended)
  /// [volume] - Volume level (0.0 to 1.0)
  Future<void> startTone(double frequency, double volume) async {
    if (_isPlaying) return;

    await _ensureInitialized();

    _currentVolume = volume;
    _isPlaying = true;

    try {
      // Set volume
      if (_player != null) {
        await _player!.setVolume(volume);
      }

      // For Stage 2, we'll use a generated tone URL
      // In production, you would generate PCM data or use pre-generated tone files
      // For now, we simulate with a placeholder approach

      // Generate and play tone using platform-specific audio
      await _playGeneratedTone(frequency);
    } catch (e) {
      debugPrint('Error starting tone: $e');
      _isPlaying = false;
      rethrow;
    }
  }

  /// Play a generated tone using platform audio
  Future<void> _playGeneratedTone(double frequency) async {
    if (_player == null) return;

    try {
      // For Stage 2, we use a simple approach:
      // Generate WAV bytes with a generated sine wave
      final wavBytes = _generateWavBytes(frequency, duration: 10.0);

      if (_player != null) {
        await _player!.play(BytesSource(wavBytes), volume: _currentVolume);
      }
    } catch (e) {
      debugPrint('Error playing generated tone: $e');
      // Fallback: try to play from assets if available
      // await _player!.play(Source.asset('assets/sounds/tone.wav'));
    }
  }

  /// Generate WAV bytes for a sine wave tone
  /// This creates a simple sine wave tone
  Uint8List _generateWavBytes(double frequency, {double duration = 10.0}) {
    const sampleRate = 44100;
    const channels = 1;
    const bitsPerSample = 16;

    final numSamples = (sampleRate * duration).round();
    final bytesPerSample = bitsPerSample ~/ 8;
    final byteRate = sampleRate * channels * bytesPerSample;
    final blockSize = channels * bytesPerSample;
    final dataSize = numSamples * channels * bytesPerSample;
    final fileSize = 36 + dataSize;

    // WAV header
    final header = <int>[];

    // RIFF chunk descriptor
    header.addAll('RIFF'.codeUnits);
    header.addAll(_intToLittleEndian(fileSize, 4));
    header.addAll('WAVE'.codeUnits);

    // fmt sub-chunk
    header.addAll('fmt '.codeUnits);
    header.addAll(_intToLittleEndian(16, 4)); // Subchunk1Size (16 for PCM)
    header.addAll(_intToLittleEndian(1, 2)); // AudioFormat (1 for PCM)
    header.addAll(_intToLittleEndian(channels, 2));
    header.addAll(_intToLittleEndian(sampleRate, 4));
    header.addAll(_intToLittleEndian(byteRate, 4));
    header.addAll(_intToLittleEndian(blockSize, 2));
    header.addAll(_intToLittleEndian(bitsPerSample, 2));

    // data sub-chunk
    header.addAll('data'.codeUnits);
    header.addAll(_intToLittleEndian(dataSize, 4));

    // Generate sine wave samples with attack/release envelope
    final attackSamples = (sampleRate * 0.01).round(); // 10ms attack
    final releaseSamples = (sampleRate * 0.05).round(); // 50ms release

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Calculate sine wave value
      double sample = math.sin(2 * math.pi * frequency * t);

      // Apply envelope
      double envelope;
      if (i < attackSamples) {
        // Attack: linear fade in over 10ms
        envelope = i / attackSamples;
      } else if (i >= numSamples - releaseSamples) {
        // Release: linear fade out over last 50ms
        envelope = (numSamples - i) / releaseSamples;
      } else {
        envelope = 1.0;
      }

      // Apply volume and envelope
      sample *= _currentVolume * envelope;

      // Convert to 16-bit PCM
      final pcmSample = (sample * 32767).clamp(-32768, 32767).toInt();

      // Add bytes (little-endian)
      header.add(pcmSample & 0xFF);
      header.add((pcmSample >> 8) & 0xFF);
    }

    return Uint8List.fromList(header);
  }

  /// Convert integer to little-endian bytes
  List<int> _intToLittleEndian(int value, int bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes; i++) {
      result.add(value & 0xFF);
      value >>= 8;
    }
    return result;
  }

  /// Stop playing the tone with smooth release
  Future<void> stopTone() async {
    if (!_isInitialized || _player == null || !_isPlaying) return;

    try {
      if (_player != null) {
        await _player!.stop();
      }
      _isPlaying = false;
    } catch (e) {
      debugPrint('Error stopping tone: $e');
    }
  }

  /// Update volume while playing
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    if (_player != null && _isInitialized) {
      await _player!.setVolume(_currentVolume);
    }
  }

  /// Update frequency while playing
  Future<void> setFrequency(double frequency) async {
    // Restart tone with new frequency
    if (_isPlaying) {
      await stopTone();
      await startTone(frequency, _currentVolume);
    }
  }

  /// Check if currently playing
  bool get isPlaying => _isPlaying;

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopTone();
      if (_player != null) {
        if (_player != null) {
          await _player!.dispose();
          _player = null;
        }
        _player = null;
      }
      _isInitialized = false;
      _isPlaying = false;
    } catch (e) {
      debugPrint('Error disposing tone generator: $e');
    }
  }
}
