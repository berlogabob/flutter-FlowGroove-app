import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Click-free reference tone generator backed by SoLoud's native oscillator.
class ToneGenerator {
  AudioSource? _source;
  SoundHandle? _handle;
  double _currentVolume = 0.5;
  double _currentFrequency = 440;
  bool _disposed = false;
  int _operationId = 0;

  bool get isPlaying => _handle != null;

  Future<void> _ensureInitialized() async {
    if (SoLoud.instance.isInitialized) return;
    await SoLoud.instance.init(
      bufferSize: 512,
      channels: Channels.mono,
      sampleRate: 44100,
    );
  }

  Future<AudioSource> _ensureSource() async {
    await _ensureInitialized();
    final existing = _source;
    if (existing != null) return existing;
    final source = await SoLoud.instance.loadWaveform(
      WaveForm.sin,
      false,
      1,
      0,
    );
    _source = source;
    return source;
  }

  Future<void> startTone(double frequency, double volume) async {
    if (_disposed) throw StateError('ToneGenerator has been disposed');
    final operationId = ++_operationId;
    _currentFrequency = frequency.clamp(20.0, 20000.0);
    _currentVolume = volume.clamp(0.0, 1.0);

    final source = await _ensureSource();
    if (operationId != _operationId) return;
    SoLoud.instance.setWaveformFreq(source, _currentFrequency);

    final existing = _handle;
    if (existing != null) {
      SoLoud.instance.fadeVolume(
        existing,
        _currentVolume,
        const Duration(milliseconds: 20),
      );
      return;
    }

    final handle = await SoLoud.instance.play(source, volume: 0, looping: true);
    if (operationId != _operationId) {
      await SoLoud.instance.stop(handle);
      return;
    }
    _handle = handle;
    SoLoud.instance.fadeVolume(
      handle,
      _currentVolume,
      const Duration(milliseconds: 20),
    );
  }

  Future<void> stopTone() async {
    final operationId = ++_operationId;
    final handle = _handle;
    _handle = null;
    if (handle == null || !SoLoud.instance.isInitialized) return;

    try {
      SoLoud.instance.fadeVolume(handle, 0, const Duration(milliseconds: 25));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (operationId <= _operationId && SoLoud.instance.isInitialized) {
        await SoLoud.instance.stop(handle);
      }
    } catch (error) {
      debugPrint('Error stopping tuner tone: $error');
    }
  }

  void setVolume(double volume) {
    _currentVolume = volume.clamp(0.0, 1.0);
    final handle = _handle;
    if (handle != null && SoLoud.instance.isInitialized) {
      SoLoud.instance.fadeVolume(
        handle,
        _currentVolume,
        const Duration(milliseconds: 20),
      );
    }
  }

  void setFrequency(double frequency) {
    _currentFrequency = frequency.clamp(20.0, 20000.0);
    final source = _source;
    if (source != null && SoLoud.instance.isInitialized) {
      SoLoud.instance.setWaveformFreq(source, _currentFrequency);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopTone();
    final source = _source;
    _source = null;
    if (source != null && SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.disposeSource(source);
      } catch (error) {
        debugPrint('Error disposing tuner oscillator: $error');
      }
    }
  }
}
