import 'dart:convert';

import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/musicbrainz_recording.dart';
import 'package:flowgroove/models/song_suggestion.dart';
import 'package:flowgroove/repositories/canonical_song_repository.dart';
import 'package:flowgroove/services/musicbrainz_service.dart';
import 'package:flowgroove/services/song_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SongSuggestionService', () {
    // No network stub needed: Deezer and Spotify moved server-side into
    // functions/src/metadata/resolver.js, so this service now only reaches the
    // canonical catalog (Firestore) and MusicBrainz.

    test('includes canonical catalog suggestions', () async {
      final canonicalRepo = _FakeCanonicalSongRepository([
        CanonicalSong(
          id: 'canonical-1',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          musicBrainzId: 'mb-1',
          baseBpm: 72,
          baseKey: 'Bb',
          createdAt: DateTime(2026, 5, 11),
          updatedAt: DateTime(2026, 5, 12),
        ),
      ]);
      final service = SongSuggestionService(
        canonicalRepo: canonicalRepo,
        musicBrainz: _FakeMusicBrainzService(),
      );

      final suggestions = await service.getSuggestions(
        query: 'Bohemian Rhapsody - Queen',
      );

      final canonical = suggestions.singleWhere(
        (suggestion) => suggestion.source == SuggestionSource.canonical,
      );
      expect(canonical.canonicalSongId, 'canonical-1');
      expect(canonical.musicBrainzId, 'mb-1');
      expect(canonical.bpm, 72);
      expect(canonical.key, 'Bb');
      expect(canonicalRepo.lastSearchQuery, 'Bohemian Rhapsody');
    });

    test('deduplicates canonical and MusicBrainz by external id', () async {
      final service = SongSuggestionService(
        canonicalRepo: _FakeCanonicalSongRepository([
          CanonicalSong(
            id: 'canonical-1',
            title: 'Song One',
            artist: 'Artist One',
            musicBrainzId: 'mb-1',
            createdAt: DateTime(2026, 5, 11),
            updatedAt: DateTime(2026, 5, 12),
          ),
        ]),
        musicBrainz: _FakeMusicBrainzService([
          const MusicBrainzRecording(
            id: 'mb-1',
            title: 'Song One',
            artistCredit: [
              MusicBrainzArtistCredit(
                artist: MusicBrainzArtist(id: 'artist-1', name: 'Artist One'),
              ),
            ],
          ),
        ]),
      );

      final suggestions = await service.getSuggestions(
        query: 'Song One - Artist One',
      );

      expect(
        suggestions.where((suggestion) => suggestion.musicBrainzId == 'mb-1'),
        hasLength(1),
      );
      expect(suggestions.single.musicBrainzId, 'mb-1');
      expect(suggestions.single.source, SuggestionSource.canonical);
    });
    test('ranks original above covers when artist is typed in query', () async {
      // Bare query, no " - " separator: "ride the lightning metallica".
      // MusicBrainz returns covers first; the original must outrank them (#87).
      final service = SongSuggestionService(
        musicBrainz: _FakeMusicBrainzService([
          const MusicBrainzRecording(
            id: 'mb-cover',
            title: 'Ride the Lightning',
            artistCredit: [
              MusicBrainzArtistCredit(
                artist: MusicBrainzArtist(id: 'a-cover', name: 'New Eden'),
              ),
            ],
          ),
          const MusicBrainzRecording(
            id: 'mb-original',
            title: 'Ride the Lightning',
            artistCredit: [
              MusicBrainzArtistCredit(
                artist: MusicBrainzArtist(id: 'a-metallica', name: 'Metallica'),
              ),
            ],
          ),
        ]),
      );

      final suggestions = await service.getSuggestions(
        query: 'ride the lightning metallica',
      );

      expect(suggestions, isNotEmpty);
      expect(suggestions.first.artist, 'Metallica');
    });

  });
}

class _FakeCanonicalSongRepository implements CanonicalSongRepository {
  _FakeCanonicalSongRepository(this.songs);

  final List<CanonicalSong> songs;
  String? lastSearchQuery;

  @override
  Future<int> count() async => songs.length;

  @override
  Future<CanonicalSong> create(CanonicalSong song) async => song;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => songs.any((song) => song.id == id);

  @override
  Future<CanonicalSong?> getByISRC(String isrc) async =>
      _firstWhereOrNull((song) => song.isrc == isrc);

  @override
  Future<CanonicalSong?> getById(String id) async =>
      _firstWhereOrNull((song) => song.id == id);

  @override
  Future<CanonicalSong?> getByMusicBrainzId(String mbId) async =>
      _firstWhereOrNull((song) => song.musicBrainzId == mbId);

  @override
  Future<List<CanonicalSong>> search({
    required String query,
    int limit = 20,
  }) async {
    lastSearchQuery = query;
    final normalizedQuery = query.toLowerCase();
    return songs
        .where(
          (song) =>
              normalizedQuery.contains(song.title.toLowerCase()) ||
              normalizedQuery.contains(song.artist.toLowerCase()) ||
              song.title.toLowerCase().contains(normalizedQuery) ||
              song.artist.toLowerCase().contains(normalizedQuery),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<CanonicalSong>> searchByTitle({
    required String titlePrefix,
    int limit = 20,
  }) async => search(query: titlePrefix, limit: limit);

  @override
  Future<void> update(CanonicalSong song) async {}

  CanonicalSong? _firstWhereOrNull(bool Function(CanonicalSong song) test) {
    for (final song in songs) {
      if (test(song)) return song;
    }
    return null;
  }
}

class _FakeMusicBrainzService extends MusicBrainzService {
  _FakeMusicBrainzService([this.recordings = const []]);

  final List<MusicBrainzRecording> recordings;

  @override
  Future<List<MusicBrainzRecording>> searchRecording({
    required String title,
    String? artist,
    int limit = 10,
    int offset = 0,
  }) async => recordings.take(limit).toList();
}
