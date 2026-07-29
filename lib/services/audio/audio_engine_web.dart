// Web-only audio engine using Web Audio API
// ignore_for_file: web_unsafe_total

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Audio engine for metronome sound synthesis
/// Uses Web Audio API for Flutter Web
/// For mobile, this class is not used (audioplayers would be needed)
class AudioEngine {
  web.AudioContext? _audioContext;
  bool _initialized = false;
  final List<(web.OscillatorNode, double)> _scheduled = [];

  /// Initialize audio context (must be called after user interaction)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _audioContext = web.AudioContext();
      _initialized = true;
      debugPrint('AudioContext initialized');
    } catch (e) {
      debugPrint('Failed to initialize AudioContext: $e');
    }
  }

  /// Web uses lazy AudioContext initialization, so pre-warm is a no-op.
  Future<void> preWarmPlayers() async {}

  /// Current AudioContext time in seconds, or null before initialization.
  /// This is the audio hardware clock — the reference for [scheduleClick].
  double? get currentContextTime => _audioContext?.currentTime;

  /// Schedule a click at an exact AudioContext time (lookahead scheduling).
  /// Unlike [playClick], the oscillator starts on the audio clock, so timing
  /// is immune to Dart timer jitter and tab throttling.
  void scheduleClick({
    required double atTime,
    required String waveType,
    required double volume,
    required double frequency,
  }) {
    final context = _audioContext;
    if (!_initialized || context == null) return;

    try {
      final oscillator = context.createOscillator();
      final gainNode = context.createGain();
      oscillator.type = waveType;
      oscillator.frequency.value = frequency;

      gainNode.gain.setValueAtTime(0, atTime);
      gainNode.gain.linearRampToValueAtTime(volume, atTime + 0.001);
      gainNode.gain.exponentialRampToValueAtTime(0.001, atTime + 0.04);

      oscillator.connect(gainNode);
      gainNode.connect(context.destination);
      oscillator
        ..start(atTime)
        ..stop(atTime + 0.04);

      // Prune finished nodes by time — cheaper than onended JS callbacks.
      final now = context.currentTime;
      _scheduled
        ..removeWhere((entry) => entry.$2 < now)
        ..add((oscillator, atTime + 0.04));
    } catch (e) {
      debugPrint('Error scheduling click: $e');
    }
  }

  /// Cancel clicks scheduled via [scheduleClick] that have not played yet.
  void cancelScheduled() {
    for (final (oscillator, _) in _scheduled) {
      try {
        oscillator.stop(0);
      } catch (_) {
        // Already stopped/ended.
      }
    }
    _scheduled.clear();
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
      oscillator
        ..start(now)
        ..stop(now + 0.04);
    } catch (e) {
      debugPrint('Error playing click: $e');
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
    await Future<void>.delayed(const Duration(milliseconds: 200));
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
    cancelScheduled();
    _audioContext?.close();
    _initialized = false;
  }
}
