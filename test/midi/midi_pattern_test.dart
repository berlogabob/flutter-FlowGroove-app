import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';

void main() {
  test('pattern json round trip + totalSteps', () {
    final p = MidiPattern(
      name: 'rock', bars: 2, beatsPerBar: 4, stepsPerBeat: 4,
      hits: [MidiHit(step: 0, note: 36, vel: 100), MidiHit(step: 4, note: 38, vel: 90)],
    );
    expect(p.totalSteps, 32);
    final q = MidiPattern.fromJson(p.toJson());
    expect(q.name, 'rock');
    expect(q.hits.length, 2);
    expect(q.hits[1].note, 38);
    expect(q.hits[1].vel, 90);
  });
  test('fromJson tolerates missing fields', () {
    final p = MidiPattern.fromJson({});
    expect(p.bars, 1);
    expect(p.hits, isEmpty);
  });
  test('drum map', () {
    expect(laneForNote(36), DrumLane.kick);
    expect(laneForNote(35), DrumLane.kick);
    expect(laneForNote(38), DrumLane.snare);
    expect(laneForNote(42), DrumLane.hatClosed);
    expect(laneForNote(46), DrumLane.hatOpen);
    expect(laneForNote(49), DrumLane.crash);
    expect(laneForNote(51), DrumLane.ride);
    expect(laneForNote(1), isNull);
  });
}
