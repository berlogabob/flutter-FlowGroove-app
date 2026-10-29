import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves program overrides when rebuilding song metadata', () {
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
    final first = buildMidiSongMeta(song);
    final previous = first.copyWith(
      tracks: [first.tracks[0].copyWith(programOverride: 19)],
    );

    final second = buildMidiSongMeta(song, previous: previous);

    expect(second.tracks[0].programOverride, 19);
  });
}
