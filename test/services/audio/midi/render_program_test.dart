import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/backing_stem_builder.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
import 'package:flowgroove/services/audio/midi/midi_track_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

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
      notes: [MidiNote(tick: 0, dur: 480, pitch: 60, vel: 100)],
    ),
  ],
);

void main() {
  test('renderMidiTrack uses the program for keys notes', () {
    final piano = renderMidiTrack(
      song: song,
      track: song.tracks.single,
      role: MidiRole.keys,
      program: 0,
      sampleRate: 8000,
    );
    final organ = renderMidiTrack(
      song: song,
      track: song.tracks.single,
      role: MidiRole.keys,
      program: 19,
      sampleRate: 8000,
    );

    expect(piano, contains(isNot(0)));
    expect(organ, contains(isNot(0)));
    expect(organ.length, piano.length);
    expect(organ, isNot(orderedEquals(piano)));
  });

  test('buildBackingStems honors the track program override', () async {
    final meta = buildMidiSongMeta(song);
    final piano = await buildBackingStems(
      song: song,
      meta: meta,
      renderBpm: 120,
      sampleRate: 8000,
    );
    final organ = await buildBackingStems(
      song: song,
      meta: meta.copyWith(
        tracks: [meta.tracks.single.copyWith(programOverride: 19)],
      ),
      renderBpm: 120,
      sampleRate: 8000,
    );

    expect(piano.keys, ['Harmony']);
    expect(organ.keys, ['Harmony']);
    expect(piano['Harmony'], contains(isNot(0)));
    expect(organ['Harmony'], contains(isNot(0)));
    expect(organ['Harmony']!.length, piano['Harmony']!.length);
    expect(organ['Harmony'], isNot(orderedEquals(piano['Harmony']!)));
  });
}
