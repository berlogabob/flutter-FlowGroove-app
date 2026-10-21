import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/backing_stem_builder.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
import 'package:flowgroove/services/audio/midi/midi_track_renderer.dart';
import 'package:flowgroove/utils/bar_math.dart';
import 'package:flutter_test/flutter_test.dart';

const sampleRate = 8000;
const ppq = 480;
const ticksPerBar = ppq * 4;

MidiTrackData track(int index, String name, List<MidiNote> notes) =>
    MidiTrackData(
      index: index,
      name: name,
      channel: name == 'Drums' ? 9 : 0,
      program: 0,
      notes: notes,
    );

MidiSongData song(List<MidiTrackData> tracks) => MidiSongData(
  ppq: ppq,
  tempos: const [TempoChange(tick: 0, microsPerQuarter: 500000)],
  timeSigs: const [TimeSigChange(tick: 0, numerator: 4, denominator: 4)],
  tracks: tracks,
);

int frame(int bar, double bpm) => barStartFrame(
  bar: bar,
  ticksPerBar: 4,
  intervalMicros: 60000000 / bpm,
  sampleRate: sampleRate,
  epochFrame: 0,
);

void main() {
  for (final bpm in [90.0, 121.0, 137.0, 240.0]) {
    test(
      '16 bars have equal stem lengths and exact bar-5 onset at $bpm',
      () async {
        final input = song([
          track(0, 'Drums', const [
            MidiNote(tick: 5 * ticksPerBar, dur: ppq, pitch: 36, vel: 127),
          ]),
          track(1, 'Bass', const [
            MidiNote(
              tick: 16 * ticksPerBar - ppq,
              dur: ppq,
              pitch: 40,
              vel: 100,
            ),
          ]),
        ]);
        var yields = 0;
        final stems = await buildBackingStems(
          song: input,
          renderBpm: bpm,
          sampleRate: sampleRate,
          yieldHook: () async {
            yields++;
          },
        );
        expect(stems.keys, unorderedEquals(['Drums', 'Bass']));
        expect(stems.length, lessThanOrEqualTo(4));
        for (final stem in stems.values) {
          expect(stem.length, frame(16, bpm));
        }
        final drums = stems['Drums']!;
        final onset = drums.indexWhere((value) => value != 0);
        expect(onset, closeTo(frame(5, bpm), 1));
        expect(stems['Bass'], contains(isNot(0)));
        expect(yields, greaterThan(16 * 4 * 60 / bpm));
      },
    );
  }

  test('groups all roles into four stems and honors track settings', () async {
    final input = song([
      for (final role in MidiRole.values)
        track(role.index, role.name, const [
          MidiNote(tick: 0, dur: ppq, pitch: 38, vel: 100),
        ]),
    ]);
    final detected = buildMidiSongMeta(input);
    final meta = detected.copyWith(
      tracks: [
        for (final setting in detected.tracks)
          setting.copyWith(roleOverride: MidiRole.values[setting.index]),
      ],
    );
    final stems = await buildBackingStems(
      song: input,
      meta: meta,
      renderBpm: 120,
      sampleRate: sampleRate,
    );
    expect(stems.keys, unorderedEquals(['Drums', 'Bass', 'Harmony', 'Lead']));
    final muted = await buildBackingStems(
      song: input,
      meta: meta.copyWith(
        tracks: [
          for (final setting in meta.tracks)
            setting.copyWith(
              mute: setting.effectiveRole != MidiRole.bass,
              volume: 0,
            ),
        ],
      ),
      renderBpm: 120,
      sampleRate: sampleRate,
    );
    expect(muted.keys, ['Bass']);
    expect(muted['Bass']!.every((value) => value == 0), isTrue);
  });

  test(
    'sustain crosses yields without restarting; final release is cut',
    () async {
      final input = song([
        track(0, 'Lead', const [
          MidiNote(tick: 0, dur: ticksPerBar, pitch: 69, vel: 100),
        ]),
      ]);
      final stems = await buildBackingStems(
        song: input,
        renderBpm: 60,
        sampleRate: sampleRate,
      );
      final reference = renderMidiTrack(
        song: input,
        track: input.tracks.single,
        role: MidiRole.lead,
        sampleRate: sampleRate,
        bpmScale: 0.5,
      );
      expect(stems['Lead'], orderedEquals(reference.take(frame(1, 60))));
      expect(reference.length, greaterThan(stems['Lead']!.length));
    },
  );

  test('flattens tempo changes onto the supplied target bar grid', () async {
    final original = song([
      track(0, 'Drums', const [
        MidiNote(tick: 5 * ticksPerBar, dur: ppq, pitch: 36, vel: 127),
      ]),
    ]);
    final input = MidiSongData(
      ppq: ppq,
      tempos: const [
        TempoChange(tick: 0, microsPerQuarter: 500000),
        TempoChange(tick: ticksPerBar, microsPerQuarter: 250000),
      ],
      timeSigs: original.timeSigs,
      tracks: original.tracks,
    );
    final stems = await buildBackingStems(
      song: input,
      renderBpm: 137,
      ticksPerBar: 8,
      intervalMicros: 30000000 / 137,
      sampleRate: sampleRate,
    );
    expect(stems['Drums']!.length, frame(6, 137));
    expect(
      stems['Drums']!.indexWhere((value) => value != 0),
      closeTo(frame(5, 137), 1),
    );
  });

  test('empty songs return no stems and invalid grids fail', () async {
    expect(await buildBackingStems(song: song([]), renderBpm: 120), isEmpty);
    for (final bpm in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        buildBackingStems(song: song([]), renderBpm: bpm),
        throwsArgumentError,
      );
    }
    await expectLater(
      buildBackingStems(song: song([]), renderBpm: 120, sampleRate: 0),
      throwsArgumentError,
    );
  });
}
