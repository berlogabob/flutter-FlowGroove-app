import 'dart:convert';
import 'dart:typed_data';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/midi_song_facts.dart';
import 'package:flowgroove/services/audio/midi/smf_song_parser.dart';
import 'package:flutter_test/flutter_test.dart';

MidiSongData _song({
  List<TempoChange> tempos = const [],
  List<List<MidiNote>> tracks = const [],
}) => MidiSongData(
  ppq: 480,
  tempos: tempos,
  timeSigs: const [],
  tracks: [
    for (var i = 0; i < tracks.length; i++)
      MidiTrackData(
        index: i,
        name: 'Track ${i + 1}',
        channel: i,
        program: 0,
        notes: tracks[i],
      ),
  ],
);

List<int> _intBytes(int value, int length) => [
  for (var i = length - 1; i >= 0; i--) (value >> (8 * i)) & 255,
];

Uint8List _smf(List<List<int>> tracks) => Uint8List.fromList([
  ...'MThd'.codeUnits,
  ..._intBytes(6, 4),
  ..._intBytes(1, 2),
  ..._intBytes(tracks.length, 2),
  ..._intBytes(480, 2),
  for (final track in tracks) ...[
    ...'MTrk'.codeUnits,
    ..._intBytes(track.length, 4),
    ...track,
  ],
]);

void main() {
  test('matches the real song tempo, duration and lead-in', () {
    final facts = factsOf(
      _song(
        tempos: const [TempoChange(tick: 0, microsPerQuarter: 483870)],
        tracks: const [
          [
            MidiNote(tick: 1920, dur: 480, pitch: 60, vel: 100),
            MidiNote(tick: 30240, dur: 480, pitch: 64, vel: 100),
          ],
        ],
      ),
    );

    expect(facts.bpm, closeTo(124.0, 0.001));
    expect(facts.bars, 16);
    expect(facts.leadInBars, 1);
    expect(facts.hasTempoEvent, isTrue);
  });

  test('empty songs default to 120 BPM, zero bars and no markers', () {
    final song = _song();
    expect(factsOf(song), (
      bpm: 120.0,
      bars: 0,
      leadInBars: 0,
      hasTempoEvent: false,
    ));
    expect(song.markers, isEmpty);
  });

  test('a later tempo event does not set the initial tempo', () {
    final facts = factsOf(
      _song(tempos: const [TempoChange(tick: 480, microsPerQuarter: 250000)]),
    );
    expect(facts.bpm, 120.0);
    expect(facts.hasTempoEvent, isFalse);
  });

  test('uses tick-zero tempo even with unsorted tempo events', () {
    final facts = factsOf(
      _song(
        tempos: const [
          TempoChange(tick: 480, microsPerQuarter: 250000),
          TempoChange(tick: 0, microsPerQuarter: 600000),
        ],
      ),
    );
    expect(facts.bpm, 100.0);
    expect(facts.hasTempoEvent, isTrue);
  });

  test('uses all notes, rounds partial bars and honors beatsPerBar', () {
    final song = _song(
      tracks: const [
        [MidiNote(tick: 3000, dur: 1801, pitch: 60, vel: 100)],
        [],
        [
          MidiNote(tick: 4000, dur: 1, pitch: 64, vel: 100),
          MidiNote(tick: 2000, dur: 1, pitch: 60, vel: 100),
        ],
      ],
    );
    expect(factsOf(song).bars, 3);
    expect(factsOf(song).leadInBars, 1);
    expect(factsOf(song, beatsPerBar: 3).bars, 4);
    expect(factsOf(song, beatsPerBar: 3).leadInBars, 1);
    expect(() => factsOf(song, beatsPerBar: 0), throwsArgumentError);
  });

  test('parses markers and cues across tracks in tick order', () {
    final text = utf8.encode('Entrée');
    final song = parseSmfSong(
      _smf([
        [0x83, 0x60, 0xFF, 0x06, 5, ...'Verse'.codeUnits, 0, 0xFF, 0x2F, 0],
        [
          0,
          0xFF,
          0x07,
          text.length,
          ...text,
          0x87,
          0x40,
          0xFF,
          0x07,
          0,
          0,
          0xFF,
          0x2F,
          0,
        ],
      ]),
    );

    expect(song.markers, [
      (tick: 0, text: 'Entrée'),
      (tick: 480, text: 'Verse'),
      (tick: 960, text: ''),
    ]);
    expect(song.tracks, isEmpty);
  });
}
