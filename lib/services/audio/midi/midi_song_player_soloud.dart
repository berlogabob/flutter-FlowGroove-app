import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'drum_player.dart';
import 'midi_song_player.dart';

MidiSongPlayer createMidiSongPlayer({SoLoud? soloud}) =>
    _SoLoudMidiSongPlayer(soloud ?? SoLoud.instance);

class _SoLoudMidiSongPlayer implements MidiSongPlayer {
  _SoLoudMidiSongPlayer(this._soloud);

  final SoLoud _soloud;
  List<Int16List> _trackBuffers = [];
  int _sampleRate = 44100;
  final _stopwatch = Stopwatch();
  final _sources = <AudioSource>[];
  final _handles = <int, SoundHandle>{};
  final _gains = <int, double>{};
  int _operationId = 0;
  bool _loaded = false;
  bool _disposed = false;

  @override
  Duration get position => _stopwatch.elapsed;

  @override
  Future<void> load(
    List<Int16List> trackBuffers, {
    int sampleRate = 44100,
  }) async {
    if (_disposed) throw StateError('MidiSongPlayer has been disposed');
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
    }
    final restart = _stopwatch.isRunning;
    final stopping = stop();
    final operationId = _operationId;
    final oldSources = _sources.toList();
    _sources.clear();
    _loaded = false;
    _stopwatch.reset();
    await stopping;
    for (final source in oldSources) {
      if (_soloud.isInitialized && _soloud.isValidAudioSource(source)) {
        await _soloud.disposeSource(source);
      }
    }
    if (operationId != _operationId) return;
    _trackBuffers = trackBuffers;
    _sampleRate = sampleRate;
    if (!_soloud.isInitialized) {
      await _soloud.init(bufferSize: 512, channels: Channels.mono);
    }
    final loaded = <AudioSource>[];
    try {
      for (var index = 0; index < trackBuffers.length; index++) {
        if (operationId != _operationId) return;
        final buffer = trackBuffers[index];
        final samples = Float32List(buffer.length);
        for (var i = 0; i < buffer.length; i++) {
          // Invert encodeDrumWav's signed scaling to preserve the PCM samples.
          samples[i] = buffer[i] / (buffer[i] < 0 ? 32768 : 32767);
        }
        loaded.add(
          await _soloud.loadMem(
            'song-${identityHashCode(this)}-$operationId-$index.wav',
            encodeDrumWav(samples, sampleRate: sampleRate),
          ),
        );
      }
      if (operationId != _operationId) return;
      _sources.addAll(loaded);
      loaded.clear();
      _loaded = true;
      if (restart) await start();
    } finally {
      for (final source in loaded) {
        if (_soloud.isInitialized && _soloud.isValidAudioSource(source)) {
          await _soloud.disposeSource(source);
        }
      }
    }
  }

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('MidiSongPlayer has been disposed');
    if (!_loaded) throw StateError('Load a song before starting');
    try {
      // The metronome can destroy our sources and reopen the shared engine.
      if (!_soloud.isInitialized ||
          _sources.any((source) => !_soloud.isValidAudioSource(source))) {
        _stopwatch.stop();
        final loading = load(_trackBuffers, sampleRate: _sampleRate);
        final operationId = _operationId;
        await loading;
        if (operationId != _operationId || !_loaded) return;
      }
      if (_stopwatch.isRunning) return;
      // SoLoud's 1024-voice pool accepts at most 1023 active voices.
      _soloud.setMaxActiveVoiceCount((_sources.length + 8).clamp(16, 1023));
      // No awaits between tracks: enqueue all voices in the same call.
      for (var index = 0; index < _sources.length; index++) {
        _handles[index] = _soloud.play(
          _sources[index],
          volume: _gains[index] ?? 1,
        );
      }
      _stopwatch
        ..reset()
        ..start();
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    ++_operationId;
    _stopwatch.stop();
    final handles = [
      for (final entry in _handles.entries)
        if (_soloud.isInitialized &&
            _soloud.isValidAudioSource(_sources[entry.key]))
          entry.value,
    ];
    _handles.clear();
    await Future.wait(handles.map(_soloud.stop));
  }

  @override
  void setTrackGain(int index, double gain) {
    final volume = gain.clamp(0.0, 1.0);
    _gains[index] = volume;
    final handle = _handles[index];
    if (handle != null &&
        _soloud.isInitialized &&
        _soloud.isValidAudioSource(_sources[index])) {
      _soloud.setVolume(handle, volume);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    final sources = _sources.toList();
    _sources.clear();
    _loaded = false;
    _trackBuffers = [];
    for (final source in sources) {
      if (_soloud.isInitialized && _soloud.isValidAudioSource(source)) {
        await _soloud.disposeSource(source);
      }
    }
  }
}
