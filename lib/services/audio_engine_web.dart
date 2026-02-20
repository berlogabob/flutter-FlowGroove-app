// Web-only audio engine using Web Audio API
// ignore_for_file: web_unsafe_total

import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Audio engine for metronome sound synthesis
/// Uses Web Audio API for Flutter Web
/// For mobile, this class is not used (audioplayers would be needed)
class AudioEngine {
  web.AudioContext? _audioContext;
  bool _initialized = false;

  /// Initialize audio context (must be called after user interaction)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _audioContext = web.AudioContext();
      _initialized = true;
      print('AudioContext initialized');
    } catch (e) {
      print('Failed to initialize AudioContext: $e');
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
    if (!_initialized || _audioContext == null) {
      await initialize();
      if (!_initialized) return;
    }

    try {
      final oscillator = _audioContext!.createOscillator();
      final gainNode = _audioContext!.createGain();

      // Set wave type (use Dart String directly, not .toJS)
      oscillator.type = waveType;

      // Frequency: accented beat = higher pitch (Reaper style)
      // Default values if not provided
      final frequency = isAccent 
          ? (accentFrequency ?? 1600) 
          : (beatFrequency ?? 800);
      oscillator.frequency.value = frequency;

      // Volume envelope to avoid clicking
      final now = _audioContext!.currentTime;
      gainNode.gain.setValueAtTime(0, now);
      gainNode.gain.linearRampToValueAtTime(volume, now + 0.001);
      gainNode.gain.exponentialRampToValueAtTime(0.001, now + 0.04);

      // Connect nodes
      oscillator.connect(gainNode);
      gainNode.connect(_audioContext!.destination);

      // Play short click (40ms like Reaper)
      oscillator.start(now);
      oscillator.stop(now + 0.04);
    } catch (e) {
      print('Error playing click: $e');
    }
  }

  /// Play test sound to verify audio works
  Future<void> playTest() async {
    await playClick(
      isAccent: true,
      waveType: 'sine',
      volume: 0.5,
      accentFrequency: 1600,
      beatFrequency: 800,
    );
    await Future.delayed(const Duration(milliseconds: 200));
    await playClick(
      isAccent: false,
      waveType: 'sine',
      volume: 0.5,
      accentFrequency: 1600,
      beatFrequency: 800,
    );
  }

  /// Dispose audio resources
  void dispose() {
    _audioContext?.close();
    _initialized = false;
  }
}
