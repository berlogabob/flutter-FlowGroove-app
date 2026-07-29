import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/services/json/song_json_codec.dart';

Song _song() {
  final now = DateTime(2026, 6, 30);
  return Song(
    id: 'x1',
    title: 'Zombie',
    artist: 'The Cranberries',
    createdAt: now,
    updatedAt: now,
    ourKey: 'Em',
    ourBPM: 84,
    tags: const ['cover', '90s'],
    sections: [
      Section(id: 's1', name: 'Verse 1', chordChart: '[Em]Another head [C]hangs'),
    ],
  );
}

void main() {
  const codec = SongJsonCodec();

  test('export → parse round-trips the user-facing fields incl. chordChart', () {
    final result = codec.parse(codec.exportSong(_song()));
    expect(result.errors, isEmpty);
    expect(result.successful, hasLength(1));
    final s = result.successful.single;
    expect(s.title, 'Zombie');
    expect(s.artist, 'The Cranberries');
    expect(s.ourKey, 'Em');
    expect(s.ourBPM, 84);
    expect(s.tags, ['cover', '90s']);
    expect(s.sections.single.name, 'Verse 1');
    expect(s.sections.single.chordChart, '[Em]Another head [C]hangs');
    expect(s.id, isNot('x1')); // a fresh id is minted on import
  });

  test('export emits the versioned envelope', () {
    final map = json.decode(codec.exportSong(_song())) as Map<String, dynamic>;
    expect(map['schemaVersion'], SongJsonCodec.schemaVersion);
    expect(map['songs'], isA<List<dynamic>>());
  });

  test('missing title is an error and the song is dropped', () {
    final r = codec.parse('{"songs":[{"artist":"x"}]}');
    expect(r.successful, isEmpty);
    expect(r.errors.single, contains('title'));
  });

  test('invalid bpm and key are errors', () {
    final r = codec.parse(
      '{"songs":[{"title":"A","ourBPM":5},{"title":"B","ourKey":"H"}]}',
    );
    expect(r.errors.length, 2);
    expect(r.errors.any((e) => e.contains('ourBPM')), isTrue);
    expect(r.errors.any((e) => e.contains('ourKey')), isTrue);
  });

  test('unknown field → warning, song still imports', () {
    final r = codec.parse('{"songs":[{"title":"A","mood":"dark"}]}');
    expect(r.successful, hasLength(1));
    expect(r.warnings.single, contains('mood'));
  });

  test('future schemaVersion warns but still parses', () {
    final r = codec.parse('{"schemaVersion":99,"songs":[{"title":"A"}]}');
    expect(r.successful, hasLength(1));
    expect(r.warnings.any((w) => w.contains('schemaVersion')), isTrue);
  });

  test('bare single-song object and bare array are accepted', () {
    expect(codec.parse('{"title":"Solo"}').successful, hasLength(1));
    expect(codec.parse('[{"title":"A"},{"title":"B"}]').successful, hasLength(2));
  });

  test('non-JSON and wrong shape produce clear errors', () {
    expect(codec.parse('not json').errors.single, contains('Invalid JSON'));
    expect(codec.parse('{"foo":1}').errors, isNotEmpty);
  });

  test('sections without ids get minted ids', () {
    final r = codec.parse('{"songs":[{"title":"A","sections":[{"name":"Intro"}]}]}');
    final sec = r.successful.single.sections.single;
    expect(sec.name, 'Intro');
    expect(sec.id, isNotEmpty);
  });
}
