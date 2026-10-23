import 'dart:typed_data';

import 'package:flowgroove/services/audio/midi/smf_parser.dart';
import 'package:flowgroove/services/audio/midi/smf_song_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Format 0, ppq 480, one track: note on/off C4 for one beat.
final _smf = Uint8List.fromList([
  0x4D, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 0, 0, 1, 0x01, 0xE0, //
  0x4D, 0x54, 0x72, 0x6B, 0, 0, 0, 13,
  0x00, 0x90, 60, 100, 0x83, 0x60, 0x80, 60, 0, 0x00, 0xFF, 0x2F, 0x00,
]);

Uint8List _rmid(Uint8List smf, {bool pad = false}) {
  final size = ByteData(4)
    ..setUint32(0, smf.length + (pad ? 1 : 0), Endian.little);
  final body = [
    ...'RMID'.codeUnits,
    ...'junk'.codeUnits,
    1,
    0,
    0,
    0,
    7,
    0,
    ...'data'.codeUnits,
    ...size.buffer.asUint8List(),
    ...smf,
    if (pad) 0,
  ];
  final total = ByteData(4)..setUint32(0, body.length, Endian.little);
  return Uint8List.fromList(
    [
      'RIFF'.codeUnits,
      total.buffer.asUint8List(),
      body,
    ].expand((e) => e).toList(),
  );
}

void main() {
  test('plain SMF passes through unwrapRmid untouched', () {
    expect(unwrapRmid(_smf), same(_smf));
  });

  test('unwrapRmid returns the embedded SMF, skipping other chunks', () {
    expect(unwrapRmid(_rmid(_smf)), _smf);
    expect(unwrapRmid(_rmid(_smf, pad: true)), [..._smf, 0]);
  });

  test('parseSmfSong reads an RMID like the bare SMF', () {
    final bare = parseSmfSong(_smf);
    final wrapped = parseSmfSong(_rmid(_smf));
    expect(wrapped.tracks.single.notes.length, bare.tracks.single.notes.length);
    expect(wrapped.ppq, 480);
  });
}
