import 'dart:typed_data';

import '../../../models/midi_pattern.dart';
import 'drum_map.dart';
import 'drum_samples.dart';

Float32List renderLane(
  MidiPattern p,
  DrumLane lane,
  double bpm,
  Float32List sample, {
  int sampleRate = 44100,
  int? frames,
}) {
  final length =
      frames ?? (p.totalSteps / p.stepsPerBeat * 60 / bpm * sampleRate).round();
  final output = Float32List(length);
  if (output.isEmpty) return output;

  for (final hit in p.hits) {
    if (laneForNote(hit.note) != lane) continue;
    final start = (hit.step / p.stepsPerBeat * 60 / bpm * sampleRate).round();
    final gain = hit.vel / 127;
    for (var i = 0; i < sample.length; i++) {
      output[(start + i) % length] += sample[i] * gain;
    }
  }
  return output;
}

/// Mixes the pattern into one mono stem on the backing engine's bar grid.
Int16List renderDrumLoop(
  MidiPattern pattern,
  double bpm, {
  required int sampleRate,
  required int frames,
}) {
  final mix = Float32List(frames);
  for (final lane in DrumLane.values) {
    if (!pattern.hits.any((hit) => laneForNote(hit.note) == lane)) continue;
    final samples = renderLane(
      pattern,
      lane,
      bpm,
      drumSample(lane, sampleRate: sampleRate),
      sampleRate: sampleRate,
      frames: frames,
    );
    for (var i = 0; i < frames; i++) {
      mix[i] += samples[i];
    }
  }
  final pcm = Int16List(frames);
  for (var i = 0; i < frames; i++) {
    final value = mix[i].clamp(-1.0, 1.0);
    pcm[i] = (value * (value < 0 ? 32768 : 32767)).round();
  }
  return pcm;
}
