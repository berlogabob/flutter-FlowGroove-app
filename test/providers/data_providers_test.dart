import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([
  SongRepository,
  BandRepository,
  SetlistRepository,
  User,
])
import 'data_providers_test.mocks.dart';

void main() {
  group('DataProviders', () {
    late ProviderContainer container;
    late MockSongRepository mockSongRepository;
    late MockBandRepository mockBandRepository;
    late MockSetlistRepository mockSetlistRepository;
    late MockUser mockUser;

    Song song(String id, {String title = 'Song'}) => Song(
      id: id,
      title: title,
      artist: 'Artist',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    setUp(() {
      mockSongRepository = MockSongRepository();
      mockBandRepository = MockBandRepository();
      mockSetlistRepository = MockSetlistRepository();
      mockUser = MockUser();
      when(mockUser.uid).thenReturn('user-1');

      // Setup default mock behaviors
      when(
        mockSongRepository.watchSongs(any),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockSongRepository.watchBandSongs(any),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockBandRepository.watchBands(any),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockSetlistRepository.watchSetlists(any),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockSetlistRepository.watchBandSetlists(any),
      ).thenAnswer((_) => Stream.value([]));

      container = ProviderContainer(
        overrides: [
          songRepositoryProvider.overrideWithValue(mockSongRepository),
          bandRepositoryProvider.overrideWithValue(mockBandRepository),
          setlistRepositoryProvider.overrideWithValue(mockSetlistRepository),
          currentUserProvider.overrideWithValue(AsyncValue.data(mockUser)),
        ],
      );
      addTearDown(container.dispose);
    });

    group('Repository Providers', () {
      test('songRepositoryProvider returns mocked instance', () {
        final repo = container.read(songRepositoryProvider);
        expect(repo, equals(mockSongRepository));
      });

      test('bandRepositoryProvider returns mocked instance', () {
        final repo = container.read(bandRepositoryProvider);
        expect(repo, equals(mockBandRepository));
      });

      test('setlistRepositoryProvider returns mocked instance', () {
        final repo = container.read(setlistRepositoryProvider);
        expect(repo, equals(mockSetlistRepository));
      });

      test('bandSetlistsProvider watches shared setlists for a band', () async {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Band Setlist',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          mockSetlistRepository.watchBandSetlists('band-1'),
        ).thenAnswer((_) => Stream.value([setlist]));

        final subscription = container.listen(
          bandSetlistsProvider('band-1'),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        verify(mockSetlistRepository.watchBandSetlists('band-1')).called(1);
      });

      test('canonicalSongSearchProvider uses repository override', () async {
        final canonicalRepo = _FakeCanonicalSongRepository([
          CanonicalSong(
            id: 'canonical-1',
            title: 'Bohemian Rhapsody',
            artist: 'Queen',
          ),
        ]);

        final scopedContainer = ProviderContainer(
          overrides: [
            canonicalSongRepositoryProvider.overrideWithValue(canonicalRepo),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          canonicalSongSearchProvider('bohemian').future,
        );

        expect(result, hasLength(1));
        expect(result.first.id, 'canonical-1');
        expect(canonicalRepo.lastQuery, 'bohemian');
      });

      test('canonicalSongSearchProvider skips short queries', () async {
        final canonicalRepo = _FakeCanonicalSongRepository([]);
        final scopedContainer = ProviderContainer(
          overrides: [
            canonicalSongRepositoryProvider.overrideWithValue(canonicalRepo),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          canonicalSongSearchProvider('q').future,
        );

        expect(result, isEmpty);
        expect(canonicalRepo.lastQuery, isNull);
      });
    });

    // #91 regression: providers must forward every live-stream emission
    // unchanged — no cache layer may re-emit stale data after fresh data.
    group('Live Stream Propagation (#91)', () {
      test('songsProvider propagates deletions from the live stream',
          () async {
        final controller = StreamController<List<Song>>();
        // Riverpod 3 pauses unlistened stream subscriptions, so an awaited
        // close() would hang waiting for the done event to be delivered.
        addTearDown(() => unawaited(controller.close()));
        when(
          mockSongRepository.watchSongs('user-1'),
        ).thenAnswer((_) => controller.stream);

        final subscription = container.listen(
          songsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        controller.add([song('song-1'), song('song-2')]);
        await pumpEventQueue();
        expect(
          container.read(songsProvider).value!.map((s) => s.id),
          ['song-1', 'song-2'],
        );

        // Delete song-2 elsewhere → the provider must drop it immediately.
        controller.add([song('song-1')]);
        await pumpEventQueue();
        expect(
          container.read(songsProvider).value!.map((s) => s.id),
          ['song-1'],
        );
      });

      test('bandsProvider propagates renames and leaves from the live stream',
          () async {
        Band band(String name) => Band(
          id: 'band-1',
          name: name,
          createdBy: 'user-1',
          createdAt: DateTime(2024),
        );
        final controller = StreamController<List<Band>>();
        // Riverpod 3 pauses unlistened stream subscriptions, so an awaited
        // close() would hang waiting for the done event to be delivered.
        addTearDown(() => unawaited(controller.close()));
        when(
          mockBandRepository.watchBands('user-1'),
        ).thenAnswer((_) => controller.stream);

        final subscription = container.listen(
          bandsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        controller.add([band('Old Name')]);
        await pumpEventQueue();
        expect(container.read(bandsProvider).value!.single.name, 'Old Name');

        controller.add([band('New Name')]);
        await pumpEventQueue();
        expect(container.read(bandsProvider).value!.single.name, 'New Name');

        // User leaves the band → the list empties immediately.
        controller.add([]);
        await pumpEventQueue();
        expect(container.read(bandsProvider).value, isEmpty);
      });

      test('bandSongsProvider propagates deletions from the live stream',
          () async {
        final controller = StreamController<List<Song>>();
        // Riverpod 3 pauses unlistened stream subscriptions, so an awaited
        // close() would hang waiting for the done event to be delivered.
        addTearDown(() => unawaited(controller.close()));
        when(
          mockSongRepository.watchBandSongs('band-1'),
        ).thenAnswer((_) => controller.stream);

        final subscription = container.listen(
          bandSongsProvider('band-1'),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        controller.add([song('song-1'), song('song-2')]);
        await pumpEventQueue();
        expect(
          container.read(bandSongsProvider('band-1')).value,
          hasLength(2),
        );

        controller.add([song('song-1')]);
        await pumpEventQueue();
        expect(
          container.read(bandSongsProvider('band-1')).value!.map((s) => s.id),
          ['song-1'],
        );
      });
    });

    group('Stream Behavior', () {
      test('songsProvider stream is accessible', () {
        final stream = container.read(songsProvider);
        expect(stream, isNotNull);
      });

      test('bandsProvider stream is accessible', () {
        final stream = container.read(bandsProvider);
        expect(stream, isNotNull);
      });

      test('setlistsProvider stream is accessible', () {
        final stream = container.read(setlistsProvider);
        expect(stream, isNotNull);
      });

      test('bandSongsProvider family provider is accessible', () {
        final stream = container.read(bandSongsProvider('band-1'));
        expect(stream, isNotNull);
      });
    });

    group('Count Providers', () {
      test('songCountProvider returns 0 for empty list', () {
        final count = container.read(songCountProvider);
        expect(count, 0);
      });

      test('bandCountProvider returns 0 for empty list', () {
        final count = container.read(bandCountProvider);
        expect(count, 0);
      });

      test('setlistCountProvider returns 0 for empty list', () {
        final count = container.read(setlistCountProvider);
        expect(count, 0);
      });
    });
  });
}

class _FakeCanonicalSongRepository implements CanonicalSongRepository {
  _FakeCanonicalSongRepository(this.songs);

  final List<CanonicalSong> songs;
  String? lastQuery;

  @override
  Future<int> count() async => songs.length;

  @override
  Future<CanonicalSong> create(CanonicalSong song) async => song;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => songs.any((song) => song.id == id);

  @override
  Future<CanonicalSong?> getByISRC(String isrc) async {
    return songs.where((song) => song.isrc == isrc).firstOrNull;
  }

  @override
  Future<CanonicalSong?> getById(String id) async {
    return songs.where((song) => song.id == id).firstOrNull;
  }

  @override
  Future<CanonicalSong?> getByMusicBrainzId(String mbId) async {
    return songs.where((song) => song.musicBrainzId == mbId).firstOrNull;
  }

  @override
  Future<List<CanonicalSong>> search({
    required String query,
    int limit = 20,
  }) async {
    lastQuery = query;
    return songs.take(limit).toList();
  }

  @override
  Future<List<CanonicalSong>> searchByTitle({
    required String titlePrefix,
    int limit = 20,
  }) async {
    return songs.take(limit).toList();
  }

  @override
  Future<void> update(CanonicalSong song) async {}
}
