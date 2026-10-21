import 'dart:convert';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const legacyJson = <String, dynamic>{
    'id': 'e1',
    'songId': 's1',
    'bandId': 'b1',
    'type': 'midi',
    'title': 'Drums',
    'body': 'Chorus groove',
    'sectionId': 'chorus',
    'versionId': 'v1',
    'status': 'active',
    'tags': ['drums'],
    'authorId': 'u1',
    'visibility': 'band',
    'createdAt': '2026-10-21T12:00:00.000',
    'updatedAt': '2026-10-21T12:00:00.000',
    'attachmentIds': ['a1'],
    'peaks': [10, 20],
    'midi': {
      'name': 'Groove',
      'bars': 1,
      'beatsPerBar': 4,
      'stepsPerBeat': 4,
      'hits': [
        {'step': 0, 'note': 36, 'vel': 100},
      ],
    },
  };
  const midiSong = MidiSongMeta(
    fileUrl: 'https://example.com/song.mid',
    ppq: 960,
    initialBpm: 135.5,
    tracks: [
      MidiTrackMeta(
        index: 0,
        name: 'Bass',
        channel: 1,
        program: 33,
        detectedRole: MidiRole.bass,
        roleOverride: MidiRole.synth,
        mute: true,
        volume: 0.75,
        noteCount: 123,
        minPitch: 28,
        maxPitch: 64,
      ),
    ],
  );

  test('legacy JSON round-trip remains byte-identical', () {
    for (final json in [
      legacyJson,
      {...legacyJson}..remove('midi'),
    ]) {
      final entry = SongLabEntry.fromJson(json);
      expect(entry.midiSong, isNull);
      expect(entry.toJson(), isNot(contains('midiSong')));
      expect(jsonEncode(entry.toJson()), jsonEncode(json));
    }
  });

  test('entry with midiSong round-trips through encoded JSON', () {
    final entry = SongLabEntry(
      id: 'e2',
      songId: 's1',
      type: LabEntryType.midi,
      authorId: 'u1',
      createdAt: DateTime(2026, 10, 21),
      updatedAt: DateTime(2026, 10, 21),
      midiSong: midiSong,
    );
    final json = entry.toJson();
    final restored = SongLabEntry.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );

    expect(json['midiSong'], midiSong.toJson());
    expect(restored.midiSong!.toJson(), midiSong.toJson());
    expect(restored.toJson(), json);
    expect(restored.midi, isNull);
    expect(restored.pattern, isNull);
  });

  test('both payloads preserve legacy midi for old builds', () {
    final json = {...legacyJson, 'midiSong': midiSong.toJson()};
    final entry = SongLabEntry.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );

    expect(entry.type, LabEntryType.midi);
    expect(entry.midi, legacyJson['midi']);
    expect(entry.pattern!.toJson(), legacyJson['midi']);
    expect(entry.toJson(), json);
    final oldBuildJson = entry.toJson()..remove('midiSong');
    expect(jsonEncode(oldBuildJson), jsonEncode(legacyJson));
  });

  test('malformed midiSong is ignored without changing legacy fields', () {
    for (final malformed in <dynamic>[
      null,
      'song.mid',
      123,
      <dynamic>[],
      {'ppq': 'invalid'},
      {'initialBpm': false},
      {'fileUrl': 123},
      {'tracks': 'invalid'},
      {
        'tracks': [null],
      },
      {
        'tracks': [
          {'volume': 'invalid'},
        ],
      },
    ]) {
      final entry = SongLabEntry.fromJson({
        ...legacyJson,
        'midiSong': malformed,
      });
      expect(entry.midiSong, isNull, reason: '$malformed');
      expect(jsonEncode(entry.toJson()), jsonEncode(legacyJson));
    }
  });

  test('copyWith sets, preserves, and replaces midiSong like midi', () {
    final legacy = SongLabEntry.fromJson(legacyJson);
    final entry = legacy.copyWith(midiSong: midiSong);
    expect(entry.midiSong, same(midiSong));
    expect(entry.midi, same(legacy.midi));
    expect(entry.copyWith(title: 'Updated').midiSong, same(midiSong));

    final replacement = midiSong.copyWith(initialBpm: 90);
    final updated = entry.copyWith(midiSong: replacement);
    expect(updated.midiSong, same(replacement));
    expect(updated.midi, same(legacy.midi));
    expect(legacy.midiSong, isNull);
  });
}
