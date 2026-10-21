import 'dart:convert';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = MidiTrackMeta(
    index: 2,
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
  );

  test('song metadata JSON round trip preserves settings and statistics', () {
    const song = MidiSongMeta(
      fileUrl: 'https://example.com/song.mid',
      ppq: 960,
      initialBpm: 135.5,
      tracks: [track],
    );
    final json = song.toJson();
    final restored = MidiSongMeta.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );

    expect(json['schemaVersion'], MidiSongMeta.schemaVersion);
    expect(restored.toJson(), json);
    expect(restored.tracks.single.effectiveRole, MidiRole.synth);
    expect(restored.tracks.single.toJson(), isNot(contains('notes')));
  });

  test('override beats detected role and can be cleared', () {
    expect(track.effectiveRole, MidiRole.synth);
    expect(track.copyWith(mute: false).roleOverride, MidiRole.synth);
    expect(
      track.copyWith(roleOverride: MidiRole.other).effectiveRole,
      MidiRole.other,
    );
    final cleared = track.copyWith(roleOverride: null);
    expect(cleared.roleOverride, isNull);
    expect(cleared.effectiveRole, MidiRole.bass);
    expect(track.roleOverride, MidiRole.synth);
  });

  test('copyWith updates metadata and preserves omitted fields', () {
    final updatedTrack = track.copyWith(
      index: 3,
      name: 'Keys',
      channel: 4,
      program: 5,
      detectedRole: MidiRole.keys,
      mute: false,
      volume: 0,
      noteCount: 20,
      minPitch: 48,
      maxPitch: 84,
    );
    expect(updatedTrack.toJson(), {
      ...track.toJson(),
      'index': 3,
      'name': 'Keys',
      'channel': 4,
      'program': 5,
      'detectedRole': 'keys',
      'mute': false,
      'volume': 0.0,
      'noteCount': 20,
      'minPitch': 48,
      'maxPitch': 84,
    });
    const song = MidiSongMeta(
      fileUrl: 'song.mid',
      ppq: 480,
      initialBpm: 120,
      tracks: [track],
    );
    expect(song.copyWith().toJson(), song.toJson());
    final updated = song.copyWith(
      fileUrl: 'new.mid',
      ppq: 960,
      initialBpm: 90,
      tracks: [updatedTrack],
    );
    expect(updated.fileUrl, 'new.mid');
    expect(updated.ppq, 960);
    expect(updated.initialBpm, 90);
    expect(updated.tracks, [updatedTrack]);
    expect(song.copyWith(fileUrl: null).fileUrl, isNull);
    expect(song.fileUrl, 'song.mid');
  });

  test('fromJson tolerates missing and null fields and unknown keys', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {
        'fileUrl': null,
        'ppq': null,
        'initialBpm': null,
        'tracks': null,
        'futureField': true,
      },
    ]) {
      final song = MidiSongMeta.fromJson(json);
      expect(song.fileUrl, isNull);
      expect(song.ppq, 480);
      expect(song.initialBpm, 120);
      expect(song.tracks, isEmpty);
    }
    final song = MidiSongMeta.fromJson({
      'schemaVersion': 99,
      'initialBpm': 100,
      'tracks': [
        {
          'detectedRole': 'future-role',
          'roleOverride': null,
          'notes': [
            {'pitch': 60},
          ],
          'futureField': true,
        },
      ],
    });
    final restored = song.tracks.single;
    expect(song.initialBpm, 100.0);
    expect(restored.toJson(), MidiTrackMeta.fromJson({}).toJson());
    expect(restored.index, 0);
    expect(restored.name, '');
    expect(restored.channel, 0);
    expect(restored.program, 0);
    expect(restored.detectedRole, MidiRole.other);
    expect(restored.roleOverride, isNull);
    expect(restored.mute, isFalse);
    expect(restored.volume, 1.0);
    expect(restored.noteCount, 0);
    expect(restored.minPitch, 0);
    expect(restored.maxPitch, 0);
    expect(restored.toJson(), isNot(contains('notes')));
    expect(
      MidiTrackMeta.fromJson({'roleOverride': 'unknown'}).roleOverride,
      MidiRole.other,
    );
  });

  test('role parser recognizes all roles and defaults to other', () {
    for (final role in MidiRole.values) {
      expect(MidiRole.parse(role.name), role);
    }
    expect(MidiRole.parse(null), MidiRole.other);
    expect(MidiRole.parse('unknown'), MidiRole.other);
  });

  test('volume defaults to one and JSON values stay within zero to one', () {
    expect(MidiTrackMeta.fromJson({'volume': -1}).volume, 0.0);
    expect(MidiTrackMeta.fromJson({'volume': 2}).volume, 1.0);
    expect(MidiTrackMeta.fromJson({'volume': 0}).volume, 0.0);
    expect(MidiTrackMeta.fromJson({'volume': 0.25}).volume, 0.25);
    expect(() => track.copyWith(volume: -0.1), throwsAssertionError);
    expect(() => track.copyWith(volume: 1.1), throwsAssertionError);
  });

  test('parsed track reports note count and pitch bounds, including empty', () {
    const data = MidiTrackData(
      index: 0,
      name: 'Piano',
      channel: 0,
      program: 0,
      notes: [
        MidiNote(tick: 0, dur: 480, pitch: 60, vel: 100),
        MidiNote(tick: 480, dur: 240, pitch: 72, vel: 90),
        MidiNote(tick: 720, dur: 120, pitch: 48, vel: 80),
      ],
    );
    expect(data.noteCount, 3);
    expect(data.minPitch, 48);
    expect(data.maxPitch, 72);
    expect(data.notes.first.tick, 0);
    expect(data.notes.first.dur, 480);
    expect(data.notes.first.vel, 100);
    const empty = MidiTrackData(
      index: 1,
      name: '',
      channel: 1,
      program: 0,
      notes: [],
    );
    expect(empty.noteCount, 0);
    expect(empty.minPitch, 0);
    expect(empty.maxPitch, 0);
  });

  test('parsed song uses the tempo at tick zero and defaults to 120 BPM', () {
    const song = MidiSongData(
      ppq: 480,
      tempos: [
        TempoChange(tick: 0, microsPerQuarter: 400000),
        TempoChange(tick: 960, microsPerQuarter: 500000),
      ],
      timeSigs: [TimeSigChange(tick: 0, numerator: 3, denominator: 4)],
      tracks: [],
    );
    expect(song.initialBpm, 150);
    expect(song.timeSigs.single.tick, 0);
    expect(song.timeSigs.single.numerator, 3);
    expect(song.timeSigs.single.denominator, 4);
    const empty = MidiSongData(ppq: 480, tempos: [], timeSigs: [], tracks: []);
    expect(empty.initialBpm, 120);
    const delayed = MidiSongData(
      ppq: 480,
      tempos: [TempoChange(tick: 480, microsPerQuarter: 400000)],
      timeSigs: [],
      tracks: [],
    );
    expect(delayed.initialBpm, 120);
  });

  test('64-track metadata JSON stays under 20000 characters', () {
    final song = MidiSongMeta(
      fileUrl: 'https://example.com/song.mid',
      ppq: 480,
      initialBpm: 120,
      tracks: List.generate(
        64,
        (index) => track.copyWith(
          index: index,
          name: 'Track $index',
          noteCount: 1000000,
        ),
      ),
    );
    expect(jsonEncode(song.toJson()).length, lessThan(20000));
  });
}
