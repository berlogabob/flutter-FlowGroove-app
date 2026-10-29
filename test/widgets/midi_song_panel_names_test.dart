import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_practice_provider.dart';
import 'package:flowgroove/services/audio/midi/midi_song_meta_builder.dart';
import 'package:flowgroove/services/audio/midi/smf_song_parser.dart';
import 'package:flowgroove/widgets/midi/midi_song_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _smf(List<List<int>> tracks) => Uint8List.fromList([
  ...'MThd'.codeUnits,
  0,
  0,
  0,
  6,
  0,
  if (tracks.length == 1) 0 else 1,
  0,
  tracks.length,
  1,
  224,
  for (final track in tracks) ...[
    ...'MTrk'.codeUnits,
    0,
    0,
    ((track.length + 4) >> 8) & 255,
    (track.length + 4) & 255,
    ...track,
    0,
    0xFF,
    0x2F,
    0,
  ],
]);

List<int> _track(String? name, int channel, int program) => [
  if (name != null) ...[0, 0xFF, 3, name.length, ...name.codeUnits],
  0,
  0xC0 | channel,
  program,
  0,
  0x90 | channel,
  60,
  100,
  1,
  0x80 | channel,
  60,
  0,
];

class _Practice extends MidiSongPracticeNotifier {
  _Practice(super.entry);

  @override
  MidiSongPracticeState build() =>
      MidiSongPracticeState(tracks: entry.midiSong!.tracks);

  @override
  Future<void> loadEntry({
    FutureOr<void> Function(SongLabEntry)? onPersist,
  }) async {}
}

class _Metronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial();
}

void main() {
  testWidgets('format-0 song title becomes distinct instrument names', (
    tester,
  ) async {
    final song = parseSmfSong(
      _smf([
        [
          0, 0xFF, 3, 4, ...'Song'.codeUnits,
          ..._track(null, 0, 33),
          0, 0xC0, 40, // A later program change must not rename the bass.
          ..._track(null, 1, 0),
          ..._track(null, 9, 16),
        ],
      ]),
    );
    final meta = buildMidiSongMeta(song);
    final names = meta.tracks.map((track) => track.name).toList();
    expect(names.toSet(), hasLength(3));
    expect(names, [
      'Electric Bass (finger) · ch 1',
      'Acoustic Grand Piano · ch 2',
      'Drums · ch 10',
    ]);
    expect(song.tracks.map((track) => track.name), everyElement('Song'));

    final entry = SongLabEntry(
      id: 'midi',
      songId: 'song',
      type: LabEntryType.midi,
      title: 'Practice song',
      authorId: 'user',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      midiSong: meta,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          midiSongPracticeProvider(entry).overrideWith(() => _Practice(entry)),
          metronomeProvider.overrideWith(_Metronome.new),
        ],
        child: MaterialApp(
          home: Scaffold(body: MidiSongPanel(entry: entry)),
        ),
      ),
    );
    await tester.pump();
    for (final name in names) {
      await tester.scrollUntilVisible(find.text(name), 200);
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  test('duplicate names across file tracks use instrument and channel', () {
    final song = parseSmfSong(
      _smf([_track('Song', 0, 33), _track('Song', 1, 0)]),
    );
    expect(buildMidiSongMeta(song).tracks.map((track) => track.name), [
      'Electric Bass (finger) · ch 1',
      'Acoustic Grand Piano · ch 2',
    ]);
  });

  test('missing and empty file names use instrument and channel', () {
    for (final name in [null, '']) {
      final song = parseSmfSong(_smf([_track(name, 1, 33)]));
      expect(
        buildMidiSongMeta(song).tracks.single.name,
        'Electric Bass (finger) · ch 2',
      );
    }
  });

  test('unique file names survive, including a numbered track name', () {
    final song = parseSmfSong(
      _smf([_track('Track 1', 0, 33), _track(null, 1, 0)]),
    );
    expect(buildMidiSongMeta(song).tracks.map((track) => track.name), [
      'Track 1',
      'Acoustic Grand Piano · ch 2',
    ]);
  });
}
