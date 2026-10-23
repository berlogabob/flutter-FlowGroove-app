import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/backing_stem_builder.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
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
  test(
    'per-track stems use track names; default stems use role groups',
    () async {
      final input = song([
        track(0, 'Drum kit', channel: 9),
        track(1, 'Electric bass', program: 33),
        track(2, 'Keys'),
      ]);
      final stems = await buildBackingStems(
        song: input,
        renderBpm: 120,
        sampleRate: sampleRate,
        perTrack: true,
      );
      expect(
        stems.keys,
        unorderedEquals(['Drum kit', 'Electric bass', 'Keys']),
      );
      for (final stem in stems.values) {
        expect(stem, contains(isNot(0)));
      }

      final grouped = await buildBackingStems(
        song: input,
        renderBpm: 120,
        sampleRate: sampleRate,
      );
      expect(grouped.keys, unorderedEquals(['Drums', 'Bass', 'Harmony']));
    },
  );

  test(
    'per-track stems include muted tracks; default stems skip them',
    () async {
      final input = song([track(0, 'Keys')]);
      final detected = buildMidiSongMeta(input);
      final meta = detected.copyWith(
        tracks: [detected.tracks.single.copyWith(mute: true)],
      );
      final stems = await buildBackingStems(
        song: input,
        meta: meta,
        renderBpm: 120,
        sampleRate: sampleRate,
        perTrack: true,
      );
      expect(stems.keys, ['Keys']);
      expect(stems['Keys'], contains(isNot(0)));

      final grouped = await buildBackingStems(
        song: input,
        meta: meta,
        renderBpm: 120,
        sampleRate: sampleRate,
      );
      expect(grouped, isEmpty);
    },
  );

  test('colliding metadata names get numbered per-track stems', () async {
    final input = song([
      track(0, 'Keys'),
      track(1, 'Keys'),
      track(2, 'Keys'),
      const MidiTrackData(
        index: 3,
        name: 'Empty',
        channel: 0,
        program: 0,
        notes: [],
      ),
    ]);
    final name = buildMidiSongMeta(input).tracks.first.name;
    final stems = await buildBackingStems(
      song: input,
      renderBpm: 120,
      sampleRate: sampleRate,
      perTrack: true,
    );
    expect(stems.keys, [name, '$name 2', '$name 3']);
  });

  test('per-track stems still apply track volume', () async {
    final input = song([track(0, 'Keys')]);
    final detected = buildMidiSongMeta(input);
    final full = await buildBackingStems(
      song: input,
      renderBpm: 120,
      sampleRate: sampleRate,
      perTrack: true,
    );
    final half = await buildBackingStems(
      song: input,
      meta: detected.copyWith(
        tracks: [detected.tracks.single.copyWith(volume: 0.5)],
      ),
      renderBpm: 120,
      sampleRate: sampleRate,
      perTrack: true,
    );
    final reference = full['Keys']!;
    final quieter = half['Keys']!;
    expect(reference, contains(isNot(0)));
    expect(quieter.length, reference.length);
    for (var i = 0; i < reference.length; i++) {
      expect(quieter[i], closeTo(reference[i] * 0.5, 1));
    }
  });
}
