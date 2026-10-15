import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../models/midi_pattern.dart';
import 'drum_loop_renderer.dart';
import 'drum_map.dart';
import 'drum_player.dart';
import 'drum_samples.dart';

DrumPlayer createDrumPlayer() => _SoLoudDrumPlayer();

class _SoLoudDrumPlayer implements DrumPlayer {
  final _clock = DrumStepClock();
  final _sources = <DrumLane, AudioSource>{};
  final _handles = <DrumLane, SoundHandle>{};
  final _gains = <DrumLane, double>{};
  MidiPattern? _pattern;
  double _bpm = 120;
  int _operationId = 0;
  bool _disposed = false;

  @override
  bool get playing => _clock.playing;

  @override
  Stream<int> get stepStream => _clock.stream;

  @override
  Future<void> load(MidiPattern p, double bpm) async {
    if (_disposed) throw StateError('DrumPlayer has been disposed');
    drumStepIndex(Duration.zero, bpm, p.stepsPerBeat, p.totalSteps);
    final restart = playing;
    final stopping = stop();
    final operationId = _operationId;
    final oldSources = _sources.values.toList();
    _sources.clear();
    _pattern = null;
    await stopping;
    for (final source in oldSources) {
      await SoLoud.instance.disposeSource(source);
    }
    if (operationId != _operationId) return;
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init(bufferSize: 512, channels: Channels.mono);
    }
    final loaded = <DrumLane, AudioSource>{};
    try {
      for (final lane in DrumLane.values) {
        if (operationId != _operationId) return;
        if (!p.hits.any((hit) => laneForNote(hit.note) == lane)) continue;
        final samples = renderLane(p, lane, bpm, drumSample(lane));
        loaded[lane] = await SoLoud.instance.loadMem(
          'drums-${identityHashCode(this)}-$operationId-${lane.name}.wav',
          encodeDrumWav(samples),
        );
      }
      if (operationId != _operationId) return;
      _sources.addAll(loaded);
      loaded.clear();
      _pattern = p;
      _bpm = bpm;
      if (restart) await start();
    } finally {
      for (final source in loaded.values) {
        await SoLoud.instance.disposeSource(source);
      }
    }
  }

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('DrumPlayer has been disposed');
    if (playing) return;
    final pattern = _pattern;
    if (pattern == null) throw StateError('Load a pattern before starting');
    try {
      // No awaits between lanes: enqueue all loops in the same call.
      for (final entry in _sources.entries) {
        _handles[entry.key] = SoLoud.instance.play(
          entry.value,
          volume: _gains[entry.key] ?? 1,
          looping: true,
        );
      }
      _clock.start(pattern, _bpm);
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    ++_operationId;
    _clock.stop();
    final handles = _handles.values.toList();
    _handles.clear();
    await Future.wait(handles.map(SoLoud.instance.stop));
  }

  @override
  void setLaneGain(DrumLane lane, double gain) {
    final volume = gain.clamp(0.0, 1.0);
    _gains[lane] = volume;
    final handle = _handles[lane];
    if (handle != null) SoLoud.instance.setVolume(handle, volume);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    final sources = _sources.values.toList();
    _sources.clear();
    for (final source in sources) {
      await SoLoud.instance.disposeSource(source);
    }
    await _clock.dispose();
  }
}
