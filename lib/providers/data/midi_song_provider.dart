import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/midi_song.dart';
import '../../models/song_lab.dart';
import '../../services/audio/midi/smf_song_parser.dart';
import 'data_providers.dart';

/// Reuses the lab audio download helper and can be overridden in tests.
final midiSongBytesFetcherProvider =
    Provider<Future<Uint8List> Function(String)>(
      (ref) => ref.watch(audioBytesFetcherProvider),
    );

// A non-autoDispose URL family is the in-memory cache, shared across entries
// and retained for replays until the provider container is disposed.
final _midiSongByUrlProvider = FutureProvider.family<MidiSongData, String>((
  ref,
  fileUrl,
) async {
  final fetch = ref.watch(midiSongBytesFetcherProvider);
  return parseSmfSong(await fetch(fileUrl));
});

final midiSongProvider = FutureProvider.family<MidiSongData?, SongLabEntry>((
  ref,
  entry,
) {
  final fileUrl = entry.midiSong?.fileUrl;
  if (fileUrl == null) return null;
  return ref.watch(_midiSongByUrlProvider(fileUrl).future);
});
