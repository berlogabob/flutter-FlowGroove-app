// Web-only reference tone generator using the Web Audio API.
// API-compatible with the SoLoud implementation in tone_generator_soloud.dart.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Click-free reference tone generator backed by a Web Audio oscillator.
class ToneGenerator {
  web.AudioContext? _context;
  web.OscillatorNode? _oscillator;
  web.GainNode? _gain;
  double _currentVolume = 0.5;
  double _currentFrequency = 440;
  bool _disposed = false;
  // Mirrors the SoLoud impl: a stop that lands while startTone is awaiting
  // context.resume() must cancel the pending start, not lose the race.
  int _operationId = 0;

  bool get isPlaying => _oscillator != null;

  Future<web.AudioContext> _ensureContext() async {
    final context = _context ??= web.AudioContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
    return context;
  }

  Future<void> startTone(double frequency, double volume) async {
    if (_disposed) throw StateError('ToneGenerator has been disposed');
    final operationId = ++_operationId;
    _currentFrequency = frequency.clamp(20.0, 20000.0);
    _currentVolume = volume.clamp(0.0, 1.0);

    final context = await _ensureContext();
    if (operationId != _operationId) return;
    final now = context.currentTime;

    final existingGain = _gain;
    if (existingGain != null) {
      // Already playing: retune and fade to the new volume.
      _oscillator!.frequency.value = _currentFrequency;
      existingGain.gain
        ..cancelScheduledValues(now)
        ..setValueAtTime(existingGain.gain.value, now)
        ..linearRampToValueAtTime(_currentVolume, now + 0.02);
      return;
    }

    // Oscillator nodes are one-shot in Web Audio: build fresh ones per start.
    final oscillator = context.createOscillator()..type = 'sine';
    oscillator.frequency.value = _currentFrequency;
    final gain = context.createGain();
    gain.gain
      ..setValueAtTime(0, now)
      ..linearRampToValueAtTime(_currentVolume, now + 0.02);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(now);
    _oscillator = oscillator;
    _gain = gain;
  }

  Future<void> stopTone() async {
    ++_operationId;
    final oscillator = _oscillator;
    final gain = _gain;
    final context = _context;
    _oscillator = null;
    _gain = null;
    if (oscillator == null || gain == null || context == null) return;

    final now = context.currentTime;
    gain.gain
      ..cancelScheduledValues(now)
      ..setValueAtTime(gain.gain.value, now)
      ..linearRampToValueAtTime(0, now + 0.025);
    oscillator.stop(now + 0.03);
  }

  void setVolume(double volume) {
    _currentVolume = volume.clamp(0.0, 1.0);
    final gain = _gain;
    final context = _context;
    if (gain == null || context == null) return;
    final now = context.currentTime;
    gain.gain
      ..cancelScheduledValues(now)
      ..setValueAtTime(gain.gain.value, now)
      ..linearRampToValueAtTime(_currentVolume, now + 0.02);
  }

  void setFrequency(double frequency) {
    _currentFrequency = frequency.clamp(20.0, 20000.0);
    _oscillator?.frequency.value = _currentFrequency;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopTone();
    final context = _context;
    _context = null;
    if (context != null) {
      await context.close().toDart;
    }
  }
}
