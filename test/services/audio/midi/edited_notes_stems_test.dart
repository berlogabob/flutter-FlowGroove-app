import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/backing_stem_builder.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
import 'package:flowgroove/services/audio/midi/note_edit.dart';
import 'package:flutter_test/flutter_test.dart';

const sampleRate = 8000;

MidiTrackData track(
  int index,
  String name, {
  int channel = 0,
  int program = 0,
}) => MidiTrackData(
  index: index,
  name: name,
  channel: channel,
  program: program,
  notes: const [MidiNote(tick: 0, dur: 480, pitch: 36, vel: 100)],
);

MidiSongData song(List<MidiTrackData> tracks) => MidiSongData(
  ppq: 480,
  tempos: const [TempoChange(tick: 0, microsPerQuarter: 500000)],
  timeSigs: const [TimeSigChange(tick: 0, numerator: 4, denominator: 4)],
  tracks: tracks,
);

void main() {
  test('per-track stems render edited notes', () async {
    final input = song([track(0, 'Keys')]);
    final detected = buildMidiSongMeta(input);
    final original = await buildBackingStems(
      song: input,
      renderBpm: 120,
      sampleRate: sampleRate,
      perTrack: true,
    );
    expect(original['Keys'], contains(isNot(0)));

    final empty = await buildBackingStems(
      song: input,
      meta: detected.copyWith(
        tracks: [detected.tracks.single.copyWith(editedNotes: <int>[])],
      ),
      renderBpm: 120,
      sampleRate: sampleRate,
      perTrack: true,
    );
    expect(empty['Keys'] ?? <int>[], everyElement(0));

    final unchanged = await buildBackingStems(
      song: input,
      meta: detected.copyWith(
        tracks: [
          detected.tracks.single.copyWith(
            editedNotes: flatFromNotes(input.tracks.single.notes),
          ),
        ],
      ),
      renderBpm: 120,
      sampleRate: sampleRate,
      perTrack: true,
    );
    expect(unchanged['Keys'], orderedEquals(original['Keys']!));

    final added = await buildBackingStems(
      song: input,
      meta: detected.copyWith(
        tracks: [
          detected.tracks.single.copyWith(
            editedNotes: flatFromNotes([
              ...input.tracks.single.notes,
              const MidiNote(tick: 480, dur: 1920, pitch: 60, vel: 100),
            ]),
          ),
        ],
      ),
      renderBpm: 120,
      sampleRate: sampleRate,
      perTrack: true,
    );
    expect(added['Keys'], hasLength(original['Keys']!.length));
    expect(added['Keys'], isNot(orderedEquals(original['Keys']!)));
  });
}
