import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../models/midi_pattern.dart';
import 'drum_loop_renderer.dart';
import 'drum_map.dart';
import 'drum_player.dart';
import 'drum_samples.dart';

DrumPlayer createDrumPlayer() => _WebDrumPlayer();

class _WebDrumPlayer implements DrumPlayer {
  final _clock = DrumStepClock();
  final _buffers = <DrumLane, web.AudioBuffer>{};
  final _sources = <DrumLane, web.AudioBufferSourceNode>{};
  final _gainNodes = <DrumLane, web.GainNode>{};
  final _gains = <DrumLane, double>{};
  web.AudioContext? _context;
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
    await stopping;
    if (operationId != _operationId) return;
    _buffers.clear();
    _pattern = null;
    final context = _context ??= web.AudioContext();
    for (final lane in DrumLane.values) {
      if (!p.hits.any((hit) => laneForNote(hit.note) == lane)) continue;
      final samples = renderLane(p, lane, bpm, drumSample(lane));
      final buffer = context.createBuffer(1, samples.length, 44100)
        ..copyToChannel(samples.toJS, 0);
      _buffers[lane] = buffer;
    }
    _pattern = p;
    _bpm = bpm;
    if (restart) await start();
  }

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('DrumPlayer has been disposed');
    if (playing) return;
    final pattern = _pattern;
    if (pattern == null) throw StateError('Load a pattern before starting');
    final operationId = ++_operationId;
    final context = _context!;
    if (context.state == 'suspended') await context.resume().toDart;
    if (operationId != _operationId) return;
    try {
      for (final entry in _buffers.entries) {
        final source = context.createBufferSource()
          ..buffer = entry.value
          ..loop = true;
        final gain = context.createGain();
        gain.gain.value = _gains[entry.key] ?? 1;
        source.connect(gain);
        gain.connect(context.destination);
        _sources[entry.key] = source;
        _gainNodes[entry.key] = gain;
      }
      final now = context.currentTime;
      for (final source in _sources.values) {
        source.start(now);
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
    for (final source in _sources.values) {
      source
        ..stop()
        ..disconnect();
    }
    for (final gain in _gainNodes.values) {
      gain.disconnect();
    }
    _sources.clear();
    _gainNodes.clear();
  }

  @override
  void setLaneGain(DrumLane lane, double gain) {
    final volume = gain.clamp(0.0, 1.0);
    _gains[lane] = volume;
    _gainNodes[lane]?.gain.value = volume;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    _buffers.clear();
    final context = _context;
    _context = null;
    if (context != null) await context.close().toDart;
    await _clock.dispose();
  }
}
