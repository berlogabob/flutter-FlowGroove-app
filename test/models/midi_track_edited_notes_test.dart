import 'dart:convert';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = MidiTrackMeta(
    index: 0,
    name: 'Piano',
    channel: 0,
    program: 0,
    detectedRole: MidiRole.keys,
    noteCount: 1,
    minPitch: 60,
    maxPitch: 60,
    editedNotes: [0, 480, 60, 100],
  );

  test('JSON round trip preserves edited notes', () {
    final json = track.toJson();
    final restored = MidiTrackMeta.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );

    expect(json['editedNotes'], [0, 480, 60, 100]);
    expect(restored.editedNotes, [0, 480, 60, 100]);
    expect(restored.toJson(), json);
  });

  test('missing edited notes default to null and are omitted from JSON', () {
    final restored = MidiTrackMeta.fromJson({});

    expect(restored.editedNotes, isNull);
    expect(restored.toJson(), isNot(contains('editedNotes')));
  });

  test('edited notes with incomplete quads default to null', () {
    final restored = MidiTrackMeta.fromJson({
      'editedNotes': [0, 480, 60],
    });

    expect(restored.editedNotes, isNull);
  });

  test('fromJson converts numeric edited notes to integers', () {
    final restored = MidiTrackMeta.fromJson({
      'editedNotes': [0.0, 480.0, 60.0, 100.0],
    });

    expect(restored.editedNotes, [0, 480, 60, 100]);
    expect(restored.editedNotes, everyElement(isA<int>()));
  });

  test(
    'copyWith preserves omitted edited notes and can replace or clear them',
    () {
      expect(track.copyWith(mute: true).editedNotes, [0, 480, 60, 100]);
      expect(track.copyWith(editedNotes: [0, 240, 62, 90]).editedNotes, [
        0,
        240,
        62,
        90,
      ]);

      final cleared = track.copyWith(editedNotes: null);

      expect(cleared.editedNotes, isNull);
      expect(cleared.toJson(), isNot(contains('editedNotes')));
      expect(track.editedNotes, [0, 480, 60, 100]);
    },
  );

  test('preserves edited notes when rebuilding song metadata', () {
    const song = MidiSongData(
      ppq: 480,
      tempos: [],
      timeSigs: [],
      tracks: [
        MidiTrackData(
          index: 0,
          name: 'Piano',
          channel: 0,
          program: 0,
          notes: [MidiNote(tick: 0, dur: 240, pitch: 62, vel: 90)],
        ),
      ],
    );
    const previous = MidiSongMeta(ppq: 480, initialBpm: 120, tracks: [track]);

    final meta = buildMidiSongMeta(song, previous: previous);

    expect(meta.tracks.single.editedNotes, [0, 480, 60, 100]);
  });
}
