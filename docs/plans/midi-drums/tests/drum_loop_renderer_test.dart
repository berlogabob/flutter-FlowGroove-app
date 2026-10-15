import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_loop_renderer.dart';

void main() {
  final p = MidiPattern(
    name: 't', bars: 1, beatsPerBar: 4, stepsPerBeat: 4,
    hits: [MidiHit(step: 0, note: 36, vel: 127), MidiHit(step: 8, note: 36, vel: 127), MidiHit(step: 4, note: 38, vel: 127)],
  );
  final sample = Float32List.fromList([1, 0.5, 0.25]);
  test('length is exact bar duration', () {
    final out = renderLane(p, DrumLane.kick, 120, sample, sampleRate: 48000);
    expect(out.length, 96000); // 4 beats * 0.5 s * 48000
  });
  test('hits land on exact frames, other lanes absent', () {
    final out = renderLane(p, DrumLane.kick, 120, sample, sampleRate: 48000);
    expect(out[0], closeTo(1, 1e-6));
    expect(out[1], closeTo(0.5, 1e-6));
    expect(out[48000], closeTo(1, 1e-6)); // step 8 = beat 2 = 1.0 s
    expect(out[12000], 0); // step 4 is snare, not kick
  });
  test('velocity scales and overlap sums', () {
    final q = MidiPattern(name: 'v', bars: 1, beatsPerBar: 4, stepsPerBeat: 4,
        hits: [MidiHit(step: 0, note: 36, vel: 64)]);
    final out = renderLane(q, DrumLane.kick, 120, sample, sampleRate: 48000);
    expect(out[0], closeTo(64 / 127, 1e-3));
  });
  test('tail past loop end wraps to start', () {
    final q = MidiPattern(name: 'w', bars: 1, beatsPerBar: 4, stepsPerBeat: 4,
        hits: [MidiHit(step: 15, note: 36, vel: 127)]);
    final out = renderLane(q, DrumLane.kick, 120, sample, sampleRate: 48000);
    final f = (15 * 0.125 * 48000).round(); // 90000
    expect(out[f], closeTo(1, 1e-6));
    expect(out.length, 96000);
  });
}
