import 'package:uuid/uuid.dart';

import '../models/canonical_song.dart';
import '../models/section.dart';
import '../models/song.dart';

const _uuid = Uuid();

/// Builds a personal-library [Song] seeded from a canonical catalog record
/// (#59): base arrangement fields become the song's original AND "our"
/// values, sections are cloned with fresh ids, and the copy stays linked via
/// [Song.canonicalSongId].
Song canonicalToSong(CanonicalSong c) {
  final now = DateTime.now();
  return Song(
    id: _uuid.v4(),
    title: c.title,
    artist: c.artist,
    album: c.album,
    createdAt: now,
    updatedAt: now,
    originalKey: c.baseKey,
    ourKey: c.baseKey,
    originalBPM: c.baseBpm,
    ourBPM: c.baseBpm,
    accentBeats: c.baseAccentBeats,
    regularBeats: c.baseRegularBeats,
    beatModes: c.baseBeatModes,
    links: c.baseLinks,
    sections: [
      for (final s in c.baseSections)
        Section(
          id: _uuid.v4(),
          name: s.name,
          notes: s.notes,
          duration: s.duration,
          colorValue: s.colorValue,
          chordChart: s.chordChart,
        ),
    ],
    spotifyId: c.spotifyId,
    musicbrainzId: c.musicBrainzId,
    isrc: c.isrc,
    durationMs: c.durationMs,
    canonicalSongId: c.id,
    isFromMusicBrainz: c.musicBrainzId != null,
  );
}
