import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_suggestion.dart';
import 'package:flowgroove/providers/song_form_provider.dart';
import 'package:flowgroove/repositories/song_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SongFormStateNotifier library v2 saves', () {
    late ProviderContainer container;
    late _RecordingSongRepository repository;

    setUp(() {
      container = ProviderContainer();
      repository = _RecordingSongRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('saves canonical suggestions as linked songs', () async {
      final notifier = container.read(songFormStateProvider.notifier);
      notifier.selectSuggestion(
        const SongSuggestion(
          id: 'canonical-1',
          title: 'Song One',
          artist: 'Artist One',
          source: SuggestionSource.canonical,
          type: SuggestionType.exact,
          canonicalSongId: 'canonical-1',
        ),
      );

      final success = await notifier.saveSong(
        songRepo: repository,
        uid: 'user-1',
      );

      expect(success, isTrue);
      expect(repository.savedSong?.canonicalSongId, 'canonical-1');
      expect(repository.updatedSong, isNull);
    });

    test('updates existing linked songs without losing v2 metadata', () async {
      final existing = Song(
        id: 'song-1',
        title: 'Old Title',
        artist: 'Artist One',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 2),
        canonicalSongId: 'canonical-1',
        libraryBaseRevision: 3,
        latestCommitId: 'commit-2',
        originalOwnerId: 'owner-1',
        originalSongId: 'source-song-1',
        isCopy: true,
        musicbrainzId: 'mb-1',
        album: 'Album One',
      );

      final notifier = container.read(songFormStateProvider.notifier)
        ..initFromSong(existing)
        ..updateTitle('New Title');

      final success = await notifier.saveSong(
        songRepo: repository,
        uid: 'user-1',
        isEditing: true,
        existingSong: existing,
      );

      final updated = repository.updatedSong;
      expect(success, isTrue);
      expect(repository.savedSong, isNull);
      expect(updated, isNotNull);
      expect(updated!.title, 'New Title');
      expect(updated.canonicalSongId, 'canonical-1');
      expect(updated.libraryBaseRevision, 3);
      expect(updated.latestCommitId, 'commit-2');
      expect(updated.originalOwnerId, 'owner-1');
      expect(updated.originalSongId, 'source-song-1');
      expect(updated.isCopy, isTrue);
      expect(updated.musicbrainzId, 'mb-1');
      expect(updated.album, 'Album One');
    });

    test(
      'clears stale canonical metadata when relinking to a different song',
      () async {
        final existing = Song(
          id: 'song-1',
          title: 'Old Title',
          artist: 'Artist One',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 2),
          canonicalSongId: 'canonical-1',
          libraryBaseRevision: 3,
          latestCommitId: 'commit-2',
          musicbrainzId: 'mb-1',
          album: 'Old Album',
        );

        final notifier = container.read(songFormStateProvider.notifier)
          ..initFromSong(existing)
          ..selectSuggestion(
            const SongSuggestion(
              id: 'canonical-2',
              title: 'New Canonical',
              artist: 'New Artist',
              source: SuggestionSource.canonical,
              type: SuggestionType.exact,
              canonicalSongId: 'canonical-2',
            ),
          );

        final success = await notifier.saveSong(
          songRepo: repository,
          uid: 'user-1',
          isEditing: true,
          existingSong: existing,
        );

        final updated = repository.updatedSong;
        expect(success, isTrue);
        expect(updated, isNotNull);
        expect(updated!.canonicalSongId, 'canonical-2');
        expect(updated.libraryBaseRevision, isNull);
        expect(updated.latestCommitId, isNull);
        expect(updated.musicbrainzId, isNull);
        expect(updated.album, isNull);
      },
    );
  });
}

class _RecordingSongRepository implements SongRepository {
  Song? savedSong;
  Song? updatedSong;
  Song? savedBandSong;
  Song? updatedBandSong;

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
  Future<void> revertBandSongToCanonical(Song song, String bandId) async {}

  @override
  Future<void> revertSongToCanonical(Song song, {String? uid}) async {}

  @override
  Future<void> saveBandSong(Song song, String bandId) async {
    savedBandSong = song;
  }

  @override
  Future<void> saveSong(Song song, {String? uid}) async {
    savedSong = song;
  }

  @override
  Future<void> updateBandSong(Song song, String bandId) async {
    updatedBandSong = song;
  }

  @override
  Future<void> updateSong(Song song, {String? uid}) async {
    updatedSong = song;
  }

  @override
  Stream<List<Song>> watchBandSongs(String bandId) => const Stream.empty();

  @override
  Stream<List<Song>> watchSongs(String uid) => const Stream.empty();
}
