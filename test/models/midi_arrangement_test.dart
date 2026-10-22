import 'dart:convert';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/section_span.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const legacyJson = <String, dynamic>{
    'fileUrl': 'https://example.com/song.mid',
    'ppq': 960,
    'initialBpm': 135.5,
    'tracks': <Map<String, dynamic>>[],
  };

  test('old JSON parses with arrangement defaults', () {
    final song = MidiSongMeta.fromJson(legacyJson);

    expect(song.startBar, 0);
    expect(song.sectionMap, isEmpty);
    expect(song.useFileTempo, isFalse);
    expect(song.endBehavior, 'loop');
  });

  test('arrangement settings round-trip with a two-span section map', () {
    const sectionMap = [
      SectionSpan(sectionId: 'verse', startBar: 2, bars: 8),
      SectionSpan(sectionId: 'chorus', startBar: 10, bars: 4),
    ];
    final song = MidiSongMeta.fromJson(legacyJson).copyWith(
      startBar: 2,
      sectionMap: sectionMap,
      useFileTempo: true,
      endBehavior: 'stop',
    );
    final json = song.toJson();
    final restored = MidiSongMeta.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );

    expect(restored.startBar, 2);
    expect(restored.sectionMap, sectionMap);
    expect(restored.useFileTempo, isTrue);
    expect(restored.endBehavior, 'stop');
    expect(restored.toJson(), json);
  });

  test('unknown end behavior defaults to loop', () {
    final song = MidiSongMeta.fromJson({...legacyJson, 'endBehavior': 'weird'});

    expect(song.endBehavior, 'loop');
  });
}
