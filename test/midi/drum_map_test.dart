import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';

void main() {
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

  test('lane labels', () {
    expect(laneLabel(DrumLane.hatClosed), 'Closed hat');
    expect(lanePadLabel(DrumLane.tomHigh), 'Hi');
  });
}
