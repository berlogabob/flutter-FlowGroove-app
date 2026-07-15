// Unit tests for SongLibraryMergeService.merge — specifically that a
// duplicate→keeper rewrite touches `items` (the source of truth once a
// setlist has any), not just the legacy `songIds` mirror. Rewriting only
// songIds is a no-op for a setlist that already has items, because
// Setlist.toJson()/effectiveItems prefer items over songIds.

import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/repositories/setlist_repository.dart';
import 'package:flowgroove/repositories/song_repository.dart';
import 'package:flowgroove/services/song_library_merge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/mocks.mocks.dart';

class _FakeSongRepository implements SongRepository {
  final List<Song> savedSongs = [];
  final List<String> deletedSongIds = [];

  @override
  Future<void> saveSong(Song song, {String? uid}) async {
    savedSongs.add(song);
  }

  @override
  Future<void> deleteSong(String songId, {String? uid}) async {
    deletedSongIds.add(songId);
  }

  @override
  Future<void> updateSong(Song song, {String? uid}) async {}

  @override
  Future<void> revertSongToCanonical(Song song, {String? uid}) async {}

  @override
  Stream<List<Song>> watchSongs(String uid) => const Stream.empty();

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
  Future<void> saveBandSong(Song song, String bandId) async {}

  @override
  Stream<List<Song>> watchBandSongs(String bandId) => const Stream.empty();

  @override
  Future<void> deleteBandSong(String bandId, String songId) async {}

  @override
  Future<void> updateBandSong(Song song, String bandId) async {}

  @override
  Future<void> revertBandSongToCanonical(Song song, String bandId) async {}

  @override
  Future<List<Song>> getSongs(String uid) async => [];

  @override
  Future<List<Song>> getBandSongs(String bandId) async => [];
}

class _FakeSetlistRepository implements SetlistRepository {
  final List<Setlist> savedSetlists = [];

  @override
  Future<void> saveSetlist(Setlist setlist, {String? uid}) async {
    savedSetlists.add(setlist);
  }

  @override
  Future<void> deleteSetlist(String setlistId, {String? uid}) async {}

  @override
  Stream<List<Setlist>> watchSetlists(String uid) => const Stream.empty();

  @override
  Future<void> saveBandSetlist(Setlist setlist, String bandId) async {
    savedSetlists.add(setlist);
  }

  @override
  Future<void> deleteBandSetlist(String bandId, String setlistId) async {}

  @override
  Stream<List<Setlist>> watchBandSetlists(String bandId) =>
      const Stream.empty();
}

void main() {
  group('SongLibraryMergeService.merge', () {
    late MockFirebaseFirestore firestore;
    late _FakeSongRepository songRepository;
    late _FakeSetlistRepository setlistRepository;
    late SongLibraryMergeService service;

    final keeperBefore = Song(
      id: 'keeper-id',
      title: 'Keeper',
      artist: 'Artist',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    final duplicate = Song(
      id: 'duplicate-id',
      title: 'Duplicate',
      artist: 'Artist',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    final merged = keeperBefore.copyWith(updatedAt: DateTime(2024));

    setUp(() {
      firestore = MockFirebaseFirestore();
      songRepository = _FakeSongRepository();
      setlistRepository = _FakeSetlistRepository();
      service = SongLibraryMergeService(firestore: firestore);

      // Stub the merge-history write: users/{uid}/song_merges.add({...})
      final usersCollection = MockCollectionReference<Map<String, dynamic>>();
      final userDoc = MockDocumentReference<Map<String, dynamic>>();
      final mergesCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mergeDoc = MockDocumentReference<Map<String, dynamic>>();

      when(firestore.collection('users')).thenReturn(usersCollection);
      when(usersCollection.doc(any)).thenReturn(userDoc);
      when(userDoc.collection('song_merges')).thenReturn(mergesCollection);
      when(mergesCollection.add(any)).thenAnswer((_) async => mergeDoc);
    });

    test(
      'rewrites items (not just the legacy songIds mirror) for a modern setlist',
      () async {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: '',
          name: 'Gig',
          items: const [
            SetlistItem(id: 'item-1', songId: 'duplicate-id', tuningPresetId: 'drop-d'),
            SetlistItem(id: 'item-2', songId: 'other-song'),
          ],
          songIds: const ['duplicate-id', 'other-song'],
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await service.merge(
          uid: 'uid-1',
          keeperBefore: keeperBefore,
          duplicate: duplicate,
          merged: merged,
          setlists: [setlist],
          songRepository: songRepository,
          setlistRepository: setlistRepository,
        );

        expect(setlistRepository.savedSetlists, hasLength(1));
        final saved = setlistRepository.savedSetlists.single;

        // items is the actual persisted source of truth (toJson derives
        // songIds from effectiveItems, which prefers items when non-empty).
        expect(saved.items.map((i) => i.songId).toList(), [
          'keeper-id',
          'other-song',
        ]);
        // The rewritten item keeps its other fields (tuningPresetId) from
        // the original occurrence.
        expect(saved.items.first.tuningPresetId, 'drop-d');
        expect(saved.items.first.id, 'item-1');

        // toJson() must reflect the fix end-to-end.
        expect(saved.toJson()['songIds'], ['keeper-id', 'other-song']);
      },
    );

    test('de-duplicates by songId, keeping the first occurrence', () async {
      final setlist = Setlist(
        id: 'setlist-2',
        bandId: '',
        name: 'Gig',
        items: const [
          SetlistItem(id: 'item-1', songId: 'keeper-id', tuningPresetId: 'std'),
          SetlistItem(id: 'item-2', songId: 'duplicate-id'),
        ],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      await service.merge(
        uid: 'uid-1',
        keeperBefore: keeperBefore,
        duplicate: duplicate,
        merged: merged,
        setlists: [setlist],
        songRepository: songRepository,
        setlistRepository: setlistRepository,
      );

      final saved = setlistRepository.savedSetlists.single;
      // Both entries resolve to keeper-id post-rewrite; only the first
      // occurrence (with its tuningPresetId) survives.
      expect(saved.items, hasLength(1));
      expect(saved.items.single.songId, 'keeper-id');
      expect(saved.items.single.tuningPresetId, 'std');
      expect(saved.items.single.id, 'item-1');
    });

    test('still rewrites songIds for a legacy setlist with empty items', () async {
      final legacySetlist = Setlist(
        id: 'setlist-3',
        bandId: '',
        name: 'Old Gig',
        songIds: const ['duplicate-id', 'other-song'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      await service.merge(
        uid: 'uid-1',
        keeperBefore: keeperBefore,
        duplicate: duplicate,
        merged: merged,
        setlists: [legacySetlist],
        songRepository: songRepository,
        setlistRepository: setlistRepository,
      );

      final saved = setlistRepository.savedSetlists.single;
      expect(saved.items, isEmpty);
      expect(saved.songIds, ['keeper-id', 'other-song']);
      // effectiveItems falls back to (rewritten) songIds.
      expect(
        saved.effectiveItems.map((i) => i.songId).toList(),
        ['keeper-id', 'other-song'],
      );
    });

    test('skips setlists that never referenced the duplicate', () async {
      final setlist = Setlist(
        id: 'setlist-4',
        bandId: '',
        name: 'Unrelated',
        songIds: const ['other-song'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      await service.merge(
        uid: 'uid-1',
        keeperBefore: keeperBefore,
        duplicate: duplicate,
        merged: merged,
        setlists: [setlist],
        songRepository: songRepository,
        setlistRepository: setlistRepository,
      );

      expect(setlistRepository.savedSetlists, isEmpty);
    });

    test('saves merged song and deletes the duplicate', () async {
      final setlist = Setlist(
        id: 'setlist-5',
        bandId: '',
        name: 'Gig',
        songIds: const ['duplicate-id'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      await service.merge(
        uid: 'uid-1',
        keeperBefore: keeperBefore,
        duplicate: duplicate,
        merged: merged,
        setlists: [setlist],
        songRepository: songRepository,
        setlistRepository: setlistRepository,
      );

      expect(songRepository.savedSongs, contains(merged));
      expect(songRepository.deletedSongIds, contains('duplicate-id'));
    });
  });
}
