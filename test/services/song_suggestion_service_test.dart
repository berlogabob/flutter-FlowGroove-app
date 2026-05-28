import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/musicbrainz_recording.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_suggestion.dart';
import 'package:flowgroove/repositories/canonical_song_repository.dart';
import 'package:flowgroove/repositories/song_repository.dart';
import 'package:flowgroove/services/musicbrainz_service.dart';
import 'package:flowgroove/services/song_suggestion_service.dart';

void main() {
  group('SongSuggestionService', () {
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
        songRepo: _FakeSongRepository(),
        canonicalRepo: canonicalRepo,
        musicBrainz: _FakeMusicBrainzService(),
        userId: 'user-1',
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
        songRepo: _FakeSongRepository(),
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
        userId: 'user-1',
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
  });
}

class _FakeSongRepository implements SongRepository {
  @override
  Future<void> addSongToBand({
    required Song song,
    required String bandId,
    String? contributorId,
    String? contributorName,
  }) async {}

  @override
  Future<void> addSongToBandById(String songId, String bandId) async {}

  @override
  Future<void> deleteBandSong(String bandId, String songId) async {}

  @override
  Future<void> deleteSong(String songId, {String? uid}) async {}

  @override
  Future<List<Song>> getBandSongs(String bandId) async => [];

  @override
  Future<List<Song>> getSongs(String uid) async => [];

  @override
  Future<void> saveBandSong(Song song, String bandId) async {}

  @override
  Future<void> saveSong(Song song, {String? uid}) async {}

  @override
  Future<void> updateBandSong(Song song, String bandId) async {}

  @override
  Future<void> updateSong(Song song, {String? uid}) async {}

  @override
  Future<void> revertBandSongToCanonical(Song song, String bandId) async {}

  @override
  Future<void> revertSongToCanonical(Song song, {String? uid}) async {}

  @override
  Stream<List<Song>> watchBandSongs(String bandId) => const Stream.empty();

  @override
  Stream<List<Song>> watchSongs(String uid) => const Stream.empty();
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
