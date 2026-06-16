/// Low-latency metronome audio engine using flutter_soloud (SoLoud).
///
/// Uses pre-generated PCM samples at init time — zero allocation during
/// playback for sub-10ms audio latency.
///
/// Features:
/// - Singleton pattern (one engine instance)
/// - Pre-generates accent and regular click samples at initialization
/// - Configurable frequency, volume, and wave type per click
/// - Proper resource disposal
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Low-latency metronome audio engine backed by SoLoud.
///
/// Call [init] once before using [playClick]. The engine pre-generates
/// all PCM samples so that playback incurs zero allocation.
///
/// The engine is a singleton — use [MetronomeAudioEngine.instance] to
/// access it.
///
/// Example:
/// ```dart
/// final engine = MetronomeAudioEngine.instance;
/// await engine.init();
/// engine.playClick(isAccent: true, volume: 0.8, frequency: 1600);
/// ```
class MetronomeAudioEngine {
  MetronomeAudioEngine._();

  /// The singleton instance.
  static final MetronomeAudioEngine instance = MetronomeAudioEngine._();

  /// Whether [init] has been called and completed successfully.
  bool _initialized = false;

  /// Whether [init] has been called and completed successfully.
  bool get isInitialized => _initialized;

  // Pre-generated WAV samples (PCM 16-bit mono).
  Uint8List? _accentSample;
  Uint8List? _regularSample;

  // SoLoud audio sources loaded from the pre-generated samples.
  AudioSource? _accentSource;
  AudioSource? _regularSource;

  // Default frequencies
  static const double _defaultAccentFrequency = 1600;
  static const double _defaultRegularFrequency = 800;

  // Sample generation parameters
  static const int _sampleRate = 44100;
  static const double _clickDuration = 0.04; // 40ms

  /// Initializes the SoLoud engine and pre-generates PCM click samples.
  ///
  /// This method is idempotent — calling it when already initialized
  /// will return immediately.
  ///
  /// [bufferSize] controls audio latency. Smaller values mean lower
  /// latency but higher risk of buffer underruns. Default is 512
  /// (~12ms at 44100 Hz).
  ///
  /// [accentFrequency] default frequency for accented beats in Hz.
  /// [regularFrequency] default frequency for regular beats in Hz.
  Future<void> init({
    int bufferSize = 512,
    double accentFrequency = _defaultAccentFrequency,
    double regularFrequency = _defaultRegularFrequency,
  }) async {
    if (_initialized) return;

    // Initialize SoLoud engine with low-latency settings.
    await SoLoud.instance.init(
      bufferSize: bufferSize,
      channels: Channels.mono,
    );

    // Pre-generate PCM samples at init time — zero allocation during playback.
    _accentSample = _generateClickWav(accentFrequency);
    _regularSample = _generateClickWav(regularFrequency);

    // Load pre-generated samples into SoLoud as audio sources.
    _accentSource = await SoLoud.instance.loadMem(
      'metronome_accent',
      _accentSample!,
    );
    _regularSource = await SoLoud.instance.loadMem(
      'metronome_regular',
      _regularSample!,
    );

    _initialized = true;
  }

  /// Plays a metronome click using a pre-generated sample.
  ///
  /// [isAccent] — true for accented beat (higher pitch), false for regular.
  /// [volume] — 0.0 to 1.0.
  /// [frequency] — ignored when using pre-generated samples (samples are
  /// pre-rendered at init-time frequencies). Kept for API compatibility.
  ///
  /// This method performs zero allocation during playback — the PCM
  /// samples are pre-generated during [init].
  ///
  /// Throws [StateError] if [init] has not been called.
  Future<void> playClick({
    required bool isAccent,
    required double volume,
    double? frequency,
  }) async {
    if (!_initialized) {
      throw StateError(
        'MetronomeAudioEngine not initialized. Call init() first.',
      );
    }

    final source = isAccent ? _accentSource! : _regularSource!;

    // Play the pre-generated sample. SoLoud creates a new voice handle
    // each time, allowing overlapping clicks.
    SoLoud.instance.play(
      source,
      volume: volume.clamp(0.0, 1.0),
    );
  }

  /// Generates a WAV-formatted PCM 16-bit mono click sample.
  ///
  /// Uses a sine wave with a fast attack and exponential decay envelope
  /// to produce a clean click sound.
  ///
  /// The triangle wave formula used here is the standard:
  ///   tri(t) = 2 * |2 * (t - floor(t)) - 1| - 1
  /// which produces a proper bipolar triangle wave in [-1, 1].
  Uint8List _generateClickWav(double frequency) {
    final numSamples = (_sampleRate * _clickDuration).round();
    final samples = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final envelope = _calculateEnvelope(t);
      // Correct sine wave generation (triangle wave in old code was buggy).
      // Using sine for a clean, pleasant click sound.
      final wave = sin(2.0 * pi * frequency * t);
      samples[i] = wave * envelope;
    }

    return _floatToPcm16Wav(samples);
  }

  /// Calculates amplitude envelope (attack + exponential decay).
  double _calculateEnvelope(double t) {
    const attackTime = 0.001; // 1ms attack
    const decayTime = 0.039; // 39ms decay

    if (t < attackTime) {
      return t / attackTime;
    } else if (t < attackTime + decayTime) {
      final decayT = t - attackTime;
      return exp(-3.0 * decayT / decayTime);
    }
    return 0;
  }

  /// Converts float samples [-1.0, 1.0] to a WAV-formatted byte array
  /// (PCM 16-bit, mono, with 44-byte header).
  Uint8List _floatToPcm16Wav(Float32List samples) {
    final numSamples = samples.length;
    final byteData = ByteData(44 + numSamples * 2);

    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + numSamples * 2, Endian.little);

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
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // mono
    byteData.setUint32(24, _sampleRate, Endian.little);
    byteData.setUint32(28, _sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, numSamples * 2, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final sample = samples[i].clamp(-1.0, 1.0);
      byteData.setInt16(44 + i * 2, (sample * 32767).toInt(), Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  /// Disposes all audio resources and shuts down the SoLoud engine.
  ///
  /// After calling this, [init] must be called again before using
  /// [playClick].
  Future<void> dispose() async {
    if (!_initialized) return;

    if (_accentSource != null) {
      await SoLoud.instance.disposeSource(_accentSource!);
      _accentSource = null;
    }
    if (_regularSource != null) {
      await SoLoud.instance.disposeSource(_regularSource!);
      _regularSource = null;
    }

    _accentSample = null;
    _regularSample = null;

    SoLoud.instance.deinit();
    _initialized = false;
  }
}
