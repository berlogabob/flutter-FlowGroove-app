import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/midi/smf_parser.dart';

Uint8List smf(List<int> track, {int ppq = 480}) {
  final b = <int>[
    0x4D,
    0x54,
    0x68,
    0x64,
    0,
    0,
    0,
    6,
    0,
    0,
    0,
    1,
    ppq >> 8,
    ppq & 255,
    0x4D,
    0x54,
    0x72,
    0x6B,
    0,
    0,
    track.length >> 8,
    track.length & 255,
    ...track,
  ];
  return Uint8List.fromList(b);
}

void main() {
  // ppq 480: kick@0, snare@480 (delta 0x83 0x60), melodic ch0 note ignored, end
  final track = [
    0, 0x99, 36, 100,
    0, 0x80, 60, 64, // ch0 note, ignored
    0x83, 0x60, 0x99, 38, 90,
    0, 0xFF, 0x2F, 0,
  ];
  test('parses channel-10 hits onto 16th grid', () {
    final p = parseDrumSmf(smf(track));
    expect(p.hits.length, 2);
    expect(p.hits[0].step, 0);
    expect(p.hits[0].note, 36);
    expect(p.hits[1].step, 4); // beat 1 = 4 sixteenths
    expect(p.hits[1].note, 38);
    expect(p.hits[1].vel, 90);
    expect(p.bars, 1);
  });
  test('bad bytes throw FormatException', () {
    expect(
      () => parseDrumSmf(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
  test('maxBars drops hits beyond the window', () {
    // second hit at tick 9600 = bar 6 (VLQ 0xCB 0x00); maxBars 4 drops it
    final t = [0, 0x99, 36, 100, 0xCB, 0x00, 0x99, 38, 100, 0, 0xFF, 0x2F, 0];
    final p = parseDrumSmf(smf(t), maxBars: 4);
    expect(p.hits.length, 1);
    expect(p.bars, 1);
  });
}
