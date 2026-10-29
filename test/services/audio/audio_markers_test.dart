import 'dart:convert';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/audio_markers.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _u32le(int v) => [
  v & 255,
  v >> 8 & 255,
  v >> 16 & 255,
  v >> 24 & 255,
];
List<int> _u32be(int v) => [
  v >> 24 & 255,
  v >> 16 & 255,
  v >> 8 & 255,
  v & 255,
];

List<int> _chunk(String id, List<int> data) => [
  ...ascii.encode(id),
  ..._u32le(data.length),
  ...data,
  if (data.length.isOdd) 0,
];

Uint8List _wav() {
  const rate = 44100;
  final cues = [(1, 0), (2, 441000), (3, 882000)];
  final body = [
    ...ascii.encode('WAVE'),
    ..._chunk('fmt ', [
      1,
      0,
      1,
      0,
      ..._u32le(rate),
      ..._u32le(rate * 2),
      2,
      0,
      16,
      0,
    ]),
    ..._chunk('data', List.filled(8, 0)),
    ..._chunk('cue ', [
      ..._u32le(cues.length),
      for (final (id, at) in cues) ...[
        ..._u32le(id),
        ..._u32le(at),
        ...ascii.encode('data'),
        ..._u32le(0),
        ..._u32le(0),
        ..._u32le(at),
      ],
    ]),
    ..._chunk('LIST', [
      ...ascii.encode('adtl'),
      for (final (id, name) in [(1, 'Intro'), (2, 'Verse'), (3, 'Chorus')])
        ..._chunk('labl', [..._u32le(id), ...utf8.encode(name), 0]),
      ..._chunk('ltxt', [
        ..._u32le(2),
        ..._u32le(441000),
        ...List.filled(12, 0),
      ]),
    ]),
  ];
  return Uint8List.fromList([
    ...ascii.encode('RIFF'),
    ..._u32le(body.length),
    ...body,
  ]);
}

List<int> _frame(String id, List<int> data) => [
  ...ascii.encode(id),
  ..._u32be(data.length),
  0,
  0,
  ...data,
];

Uint8List _mp3() {
  List<int> chap(String id, int start, int end, String title) =>
      _frame('CHAP', [
        ...ascii.encode(id),
        0,
        ..._u32be(start),
        ..._u32be(end),
        ..._u32be(0xFFFFFFFF),
        ..._u32be(0xFFFFFFFF),
        ..._frame('TIT2', [3, ...utf8.encode(title), 0]),
      ]);
  final frames = [
    ...chap('c0', 0, 15000, 'Intro'),
    ...chap('c1', 15000, 45000, 'Verse'),
  ];
  final size = frames.length;
  return Uint8List.fromList([
    ...ascii.encode('ID3'), 3, 0, 0,
    size >> 21 & 127, size >> 14 & 127, size >> 7 & 127, size & 127,
    ...frames,
    0xFF, 0xFB, 1, 2, 3, // audio junk after the tag
  ]);
}

void main() {
  test('WAV cue points with labels and a region length', () {
    final markers = readAudioMarkers(_wav());
    expect([for (final m in markers) m.ms], [0, 10000, 20000]);
    expect([for (final m in markers) m.name], ['Intro', 'Verse', 'Chorus']);
    expect(markers[1].endMs, 20000);
    expect(markers[0].endMs, isNull);
  });

  test('MP3 ID3v2.3 chapters with titles', () {
    final markers = readAudioMarkers(_mp3());
    expect(
      [for (final m in markers) (m.ms, m.endMs, m.name)],
      [(0, 15000, 'Intro'), (15000, 45000, 'Verse')],
    );
  });

  test('anything else yields no markers', () {
    expect(readAudioMarkers(Uint8List(0)), isEmpty);
    expect(
      readAudioMarkers(Uint8List.fromList(List.generate(64, (i) => i * 7))),
      isEmpty,
    );
    expect(readAudioMarkers(_wav().sublist(0, 30)), isEmpty);
  });
}
