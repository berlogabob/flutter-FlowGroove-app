import 'dart:typed_data';

import '../../../models/midi_pattern.dart';
import 'drum_map.dart';

Float32List renderLane(
  MidiPattern p,
  DrumLane lane,
  double bpm,
  Float32List sample, {
  int sampleRate = 44100,
}) {
  final length = (p.totalSteps / p.stepsPerBeat * 60 / bpm * sampleRate)
      .round();
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
