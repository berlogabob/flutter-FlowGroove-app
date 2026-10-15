import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/midi_pattern.dart';

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
}
