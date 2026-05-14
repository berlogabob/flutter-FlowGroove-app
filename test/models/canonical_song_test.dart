import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/link.dart';
import 'package:flowgroove/models/section.dart';

void main() {
  group('CanonicalSong', () {
    final createdAt = DateTime(2026, 5, 11, 18, 38);
    final updatedAt = DateTime(2026, 5, 13, 1, 30);

    test('serializes and deserializes complete catalog metadata', () {
      final song = CanonicalSong(
        id: 'mb-recording-id',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        artists: const ['Queen'],
        album: 'A Night at the Opera',
        releaseYear: 1975,
        durationMs: 354000,
        isrc: 'GBUM71029604',
        spotifyId: 'spotify-track-id',
        musicBrainzId: 'mb-recording-id',
        musicBrainzWorkId: 'mb-work-id',
        iswc: 'T-010.140.236-1',
        normalizedTitle: 'bohemian rhapsody',
        normalizedArtist: 'queen',
        genres: const ['rock'],
        disambiguation: 'original',
        schemaVersion: 2,
        canonicalRevision: 3,
        source: 'musicbrainz',
        status: 'active',
        createdBy: 'admin-1',
        baseKey: 'Bb',
        baseBpm: 72,
        baseSections: [Section(id: 'intro', name: 'Intro', duration: 2)],
        baseAccentBeats: 6,
        baseRegularBeats: 2,
        baseBeatModes: const [
          [BeatMode.accent, BeatMode.normal],
        ],
        baseLinks: [
          Link(type: Link.typeYoutubeOriginal, url: 'https://example.com'),
        ],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final restored = CanonicalSong.fromJson(song.toJson());

      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.artists, song.artists);
      expect(restored.album, song.album);
      expect(restored.releaseYear, song.releaseYear);
      expect(restored.durationMs, song.durationMs);
      expect(restored.isrc, song.isrc);
      expect(restored.spotifyId, song.spotifyId);
      expect(restored.musicBrainzId, song.musicBrainzId);
      expect(restored.musicBrainzWorkId, song.musicBrainzWorkId);
      expect(restored.iswc, song.iswc);
      expect(restored.normalizedTitle, song.normalizedTitle);
      expect(restored.normalizedArtist, song.normalizedArtist);
      expect(restored.genres, song.genres);
      expect(restored.disambiguation, song.disambiguation);
      expect(restored.schemaVersion, 2);
      expect(restored.canonicalRevision, 3);
      expect(restored.source, 'musicbrainz');
      expect(restored.status, 'active');
      expect(restored.createdBy, 'admin-1');
      expect(restored.baseKey, 'Bb');
      expect(restored.baseBpm, 72);
      expect(restored.baseSections.single.name, 'Intro');
      expect(restored.baseAccentBeats, 6);
      expect(restored.baseRegularBeats, 2);
      expect(restored.baseBeatModes.single.first, BeatMode.accent);
      expect(restored.baseLinks.single.url, 'https://example.com');
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
    });

    test('fromMusicBrainz uses MusicBrainz recording id as canonical id', () {
      final song = CanonicalSong.fromMusicBrainz(
        title: '  Come Together  ',
        artist: '  The Beatles  ',
        musicBrainzId: 'mb-id',
        musicBrainzWorkId: 'work-id',
        durationMs: 259000,
        isrc: 'GBAYE0601690',
      );

      expect(song.id, 'mb-id');
      expect(song.title, 'Come Together');
      expect(song.artist, 'The Beatles');
      expect(song.musicBrainzId, 'mb-id');
      expect(song.musicBrainzWorkId, 'work-id');
      expect(song.normalizedTitle, 'come together');
      expect(song.normalizedArtist, 'the beatles');
      expect(song.source, 'musicbrainz');
      expect(song.hasMusicBrainzData, isTrue);
      expect(song.hasISRC, isTrue);
    });

    test('display helpers expose duration and disambiguation', () {
      final song = CanonicalSong(
        id: 'song-id',
        title: 'Song',
        artist: 'Artist',
        durationMs: 185000,
        disambiguation: 'live',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(song.formattedDuration, '3:05');
      expect(song.displayTitle, 'Song (live)');
    });
  });
}
