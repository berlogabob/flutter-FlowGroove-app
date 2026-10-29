import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SongLabEntry entry({MidiSongMeta? midiSong}) => SongLabEntry(
  id: 'entry',
  songId: 'song',
  type: LabEntryType.midi,
  authorId: 'author',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  midiSong: midiSong,
);

Uint8List smf() => Uint8List.fromList([
  ...'MThd'.codeUnits,
  0, 0, 0, 6, // Header length.
  0, 0, 0, 1, 0, 96, // Format 0, one track, 96 PPQ.
  ...'MTrk'.codeUnits,
  0, 0, 0, 12, // Track length.
  0, 0x90, 60, 100, // Note on.
  96, 0x80, 60, 0, // Note off after one quarter note.
  0, 0xff, 0x2f, 0, // End of track.
]);

void main() {
  const url = 'https://example.com/song.mid';
  const meta = MidiSongMeta(fileUrl: url, ppq: 96, initialBpm: 120, tracks: []);
  late ProviderContainer container;
  late List<String> fetchedUrls;

  setUp(() {
    fetchedUrls = [];
    container = ProviderContainer(
      overrides: [
        midiSongBytesFetcherProvider.overrideWithValue((url) async {
          fetchedUrls.add(url);
          return smf();
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  test('returns null without MIDI metadata or a file URL', () async {
    for (final songMeta in <MidiSongMeta?>[
      null,
      meta.copyWith(fileUrl: null),
    ]) {
      expect(
        await container.read(
          midiSongProvider(entry(midiSong: songMeta)).future,
        ),
        isNull,
      );
    }
    expect(fetchedUrls, isEmpty);
  });

  test('fetches the URL and returns parsed song data', () async {
    final data = await container.read(
      midiSongProvider(entry(midiSong: meta)).future,
    );

    expect(fetchedUrls, [url]);
    expect(data, isA<MidiSongData>());
    expect(data!.ppq, 96);
    final track = data.tracks.single;
    expect(track.channel, 0);
    expect(track.notes.single.pitch, 60);
    expect(track.notes.single.vel, 100);
    expect(track.notes.single.tick, 0);
    expect(track.notes.single.dur, 96);
  });

  test('replays and different entries with the same URL fetch once', () async {
    final provider = midiSongProvider(entry(midiSong: meta));
    final first = await container.read(provider.future);
    await pumpEventQueue();
    expect(await container.read(provider.future), same(first));

    // Rebuilding the entry provider must still hit the URL cache.
    container.invalidate(provider);
    expect(await container.read(provider.future), same(first));
    expect(
      await container.read(midiSongProvider(entry(midiSong: meta)).future),
      same(first),
    );
    expect(fetchedUrls, [url]);
  });

  test('different URLs have separate cache entries', () async {
    await container.read(midiSongProvider(entry(midiSong: meta)).future);
    const otherUrl = 'https://example.com/other.mid';
    await container.read(
      midiSongProvider(
        entry(midiSong: meta.copyWith(fileUrl: otherUrl)),
      ).future,
    );
    expect(fetchedUrls, [url, otherUrl]);
  });

  test('an unlistened future survives a delayed byte fetch', () async {
    final bytes = Completer<Uint8List>();
    container.updateOverrides([
      midiSongBytesFetcherProvider.overrideWithValue((_) => bytes.future),
    ]);
    final future = container.read(
      midiSongProvider(entry(midiSong: meta)).future,
    );
    await pumpEventQueue();
    bytes.complete(smf());
    expect((await future)!.ppq, 96);
  });
}
