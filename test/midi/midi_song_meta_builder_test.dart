import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const song = MidiSongData(
    ppq: 960,
    tempos: [
      TempoChange(tick: 0, microsPerQuarter: 400000),
      TempoChange(tick: 960, microsPerQuarter: 500000),
    ],
    timeSigs: [],
    tracks: [
      MidiTrackData(
        index: 4,
        name: 'Percussion',
        channel: 9,
        program: 0,
        notes: [
          MidiNote(tick: 0, dur: 120, pitch: 42, vel: 100),
          MidiNote(tick: 120, dur: 120, pitch: 36, vel: 90),
        ],
      ),
      MidiTrackData(
        index: 4,
        name: 'Track 5',
        channel: 1,
        program: 33,
        notes: [MidiNote(tick: 0, dur: 480, pitch: 64, vel: 100)],
      ),
    ],
  );

  test('builds roles, statistics and default settings from song data', () {
    final meta = buildMidiSongMeta(song, fileUrl: 'song.mid');

    expect(meta.fileUrl, 'song.mid');
    expect(meta.ppq, 960);
    expect(meta.initialBpm, 150.0);
    expect(meta.tracks.map((track) => track.detectedRole), [
      MidiRole.drums,
      MidiRole.bass,
    ]);
    for (var i = 0; i < song.tracks.length; i++) {
      final data = song.tracks[i];
      final track = meta.tracks[i];
      expect(track.index, data.index);
      expect(track.channel, data.channel);
      expect(track.name, data.name);
      expect(track.program, data.program);
      expect(track.noteCount, data.noteCount);
      expect(track.minPitch, data.minPitch);
      expect(track.maxPitch, data.maxPitch);
      expect(track.roleOverride, isNull);
      expect(track.mute, isFalse);
      expect(track.volume, 1.0);
    }
  });

  test('carries settings by index and channel while refreshing metadata', () {
    final saved = buildMidiSongMeta(song).tracks.last.copyWith(
      name: 'Old name',
      program: 0,
      detectedRole: MidiRole.keys,
      noteCount: 999,
      minPitch: 0,
      maxPitch: 127,
      roleOverride: MidiRole.synth,
      mute: true,
      volume: 0.25,
    );
    final previous = MidiSongMeta(
      ppq: 480,
      initialBpm: 120,
      tracks: [saved, saved.copyWith(index: 99, channel: 9)],
    );

    final meta = buildMidiSongMeta(song, previous: previous);
    final bass = meta.tracks.last;
    expect(meta.ppq, 960);
    expect(meta.initialBpm, 150.0);
    expect(bass.roleOverride, MidiRole.synth);
    expect(bass.effectiveRole, MidiRole.synth);
    expect(bass.mute, isTrue);
    expect(bass.volume, 0.25);
    expect(bass.detectedRole, MidiRole.bass);
    expect(bass.name, 'Track 5');
    expect(bass.program, 33);
    expect(bass.noteCount, 1);
    expect(bass.minPitch, 64);
    expect(bass.maxPitch, 64);
    final drums = meta.tracks.first;
    expect(drums.roleOverride, isNull);
    expect(drums.mute, isFalse);
    expect(drums.volume, 1.0);
    expect(saved.name, 'Old name');
  });

  test('truncates track names to 80 Unicode characters', () {
    final name = '🎵' * 81;
    final meta = buildMidiSongMeta(
      MidiSongData(
        ppq: 96,
        tempos: [],
        timeSigs: [],
        tracks: [
          MidiTrackData(
            index: 0,
            name: name,
            channel: 0,
            program: 0,
            notes: [],
          ),
        ],
      ),
    );
    expect(meta.tracks.single.name, '🎵' * 80);
  });

  test('handles empty songs and tracks', () {
    const empty = MidiSongData(ppq: 480, tempos: [], timeSigs: [], tracks: []);
    final meta = buildMidiSongMeta(empty);
    expect(meta.fileUrl, isNull);
    expect(meta.initialBpm, 120.0);
    expect(meta.tracks, isEmpty);

    final track = buildMidiSongMeta(
      const MidiSongData(
        ppq: 480,
        tempos: [],
        timeSigs: [],
        tracks: [
          MidiTrackData(
            index: 0,
            name: '',
            channel: 0,
            program: 112,
            notes: [],
          ),
        ],
      ),
    ).tracks.single;
    expect(track.noteCount, 0);
    expect(track.minPitch, 0);
    expect(track.maxPitch, 0);
  });
}
