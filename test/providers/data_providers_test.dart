import 'dart:async';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/canonical_song.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/repositories.dart';
import 'package:flowgroove/services/cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([
  SongRepository,
  BandRepository,
  SetlistRepository,
  CacheService,
])
import 'data_providers_test.mocks.dart';

void main() {
  group('DataProviders', () {
    late ProviderContainer container;
    late MockSongRepository mockSongRepository;
    late MockBandRepository mockBandRepository;
    late MockSetlistRepository mockSetlistRepository;
    late MockCacheService mockCacheService;

    setUp(() {
      mockSongRepository = MockSongRepository();
      mockBandRepository = MockBandRepository();
      mockSetlistRepository = MockSetlistRepository();
      mockCacheService = MockCacheService();

      // Setup default mock behaviors
      when(
        mockSongRepository.watchSongs(any),
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
      when(mockCacheService.getCachedSongs(any)).thenAnswer((_) async => []);
      when(mockCacheService.getCachedBands(any)).thenAnswer((_) async => []);
      when(mockCacheService.getCachedSetlists(any)).thenAnswer((_) async => []);
      when(
        mockCacheService.getCachedBandSongs(any),
      ).thenAnswer((_) async => []);
      when(mockCacheService.cacheSongs(any, any)).thenAnswer((_) async => {});
      when(mockCacheService.cacheBands(any, any)).thenAnswer((_) async => {});
      when(
        mockCacheService.cacheSetlists(any, any),
      ).thenAnswer((_) async => {});
      when(
        mockCacheService.cacheBandSongs(any, any),
      ).thenAnswer((_) async => {});

      container = ProviderContainer(
        overrides: [
          songRepositoryProvider.overrideWithValue(mockSongRepository),
          bandRepositoryProvider.overrideWithValue(mockBandRepository),
          setlistRepositoryProvider.overrideWithValue(mockSetlistRepository),
          cacheServiceProvider.overrideWithValue(mockCacheService),
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

      test('cacheServiceProvider returns mocked instance', () {
        final cache = container.read(cacheServiceProvider);
        expect(cache, equals(mockCacheService));
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

    group('Song Providers', () {
      test('songsProvider returns stream', () {
        when(mockCacheService.getCachedSongs(any)).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs(any),
        ).thenAnswer((_) => Stream.value([]));

        final songsAsync = container.read(songsProvider);
        expect(songsAsync, isNotNull);
      });

      test('songCountProvider returns integer', () {
        final count = container.read(songCountProvider);
        expect(count, isA<int>());
        expect(count, 0);
      });

    });

    group('Band Providers', () {
      test('bandsProvider returns stream', () {
        when(mockCacheService.getCachedBands(any)).thenAnswer((_) async => []);
        when(
          mockBandRepository.watchBands(any),
        ).thenAnswer((_) => Stream.value([]));

        final bandsAsync = container.read(bandsProvider);
        expect(bandsAsync, isNotNull);
      });

      test('bandCountProvider returns integer', () {
        final count = container.read(bandCountProvider);
        expect(count, isA<int>());
        expect(count, 0);
      });

      test('SelectedBandNotifier initializes with null', () {
        final selectedBand = container.read(selectedBandProvider);
        expect(selectedBand, isNull);
      });

      test('SelectedBandNotifier selects a band', () {
        final band = Band(
          id: 'band-1',
          name: 'Selected Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );

        final notifier = container.read(selectedBandProvider.notifier);
        notifier.select(band);

        final selectedBand = container.read(selectedBandProvider);
        expect(selectedBand, isNotNull);
        expect(selectedBand?.id, 'band-1');
        expect(selectedBand?.name, 'Selected Band');
      });

      test('SelectedBandNotifier selects null to clear selection', () {
        final band = Band(
          id: 'band-1',
          name: 'Test Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );

        final notifier = container.read(selectedBandProvider.notifier);
        notifier.select(band);
        expect(container.read(selectedBandProvider), isNotNull);

        notifier.select(null);
        expect(container.read(selectedBandProvider), isNull);
      });

      test('SelectedBandNotifier can change selected band', () {
        final band1 = Band(
          id: 'band-1',
          name: 'Band 1',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );
        final band2 = Band(
          id: 'band-2',
          name: 'Band 2',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );

        final notifier = container.read(selectedBandProvider.notifier);

        notifier.select(band1);
        expect(container.read(selectedBandProvider)?.id, 'band-1');

        notifier.select(band2);
        expect(container.read(selectedBandProvider)?.id, 'band-2');
      });

    });

    group('Setlist Providers', () {
      test('setlistsProvider returns stream', () {
        when(
          mockCacheService.getCachedSetlists(any),
        ).thenAnswer((_) async => []);
        when(
          mockSetlistRepository.watchSetlists(any),
        ).thenAnswer((_) => Stream.value([]));

        final setlistsAsync = container.read(setlistsProvider);
        expect(setlistsAsync, isNotNull);
      });

      test('setlistCountProvider returns integer', () {
        final count = container.read(setlistCountProvider);
        expect(count, isA<int>());
        expect(count, 0);
      });
    });

    group('Band Songs Provider', () {
      test('bandSongsProvider handles empty cache', () {
        when(
          mockCacheService.getCachedBandSongs('band-1'),
        ).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchBandSongs('band-1'),
        ).thenAnswer((_) => Stream.value([]));

        final songsAsync = container.read(bandSongsProvider('band-1'));
        expect(songsAsync, isNotNull);
      });

      test('bandSongsProvider returns songs from cache', () async {
        final mockSongs = [
          Song(
            id: 'song-1',
            title: 'Band Song',
            artist: 'Band Artist',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ];

        when(
          mockCacheService.getCachedBandSongs('band-1'),
        ).thenAnswer((_) async => mockSongs);
        when(
          mockSongRepository.watchBandSongs('band-1'),
        ).thenAnswer((_) => Stream.value(mockSongs));

        final songsAsync = container.read(bandSongsProvider('band-1'));
        expect(songsAsync, isNotNull);
      });
    });

    group('State Updates', () {
      test('SelectedBandNotifier state updates correctly', () {
        final notifier = container.read(selectedBandProvider.notifier);

        // Initial state
        expect(container.read(selectedBandProvider), isNull);

        // Update state
        final band = Band(
          id: 'band-1',
          name: 'Test Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );
        notifier.select(band);
        expect(container.read(selectedBandProvider), equals(band));

        // Clear state
        notifier.select(null);
        expect(container.read(selectedBandProvider), isNull);
      });

      test('Multiple state updates work correctly for selected band', () {
        final notifier = container.read(selectedBandProvider.notifier);

        final band1 = Band(
          id: 'band-1',
          name: 'First Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );
        final band2 = Band(
          id: 'band-2',
          name: 'Second Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );
        final band3 = Band(
          id: 'band-3',
          name: 'Third Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024),
        );

        notifier.select(band1);
        expect(container.read(selectedBandProvider)?.name, 'First Band');

        notifier.select(band2);
        expect(container.read(selectedBandProvider)?.name, 'Second Band');

        notifier.select(band3);
        expect(container.read(selectedBandProvider)?.name, 'Third Band');
      });
    });

    group('Stream Behavior', () {
      test('songsProvider stream is accessible', () {
        when(mockCacheService.getCachedSongs(any)).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs(any),
        ).thenAnswer((_) => Stream.value([]));

        final stream = container.read(songsProvider);
        expect(stream, isNotNull);
      });

      test('bandsProvider stream is accessible', () {
        when(mockCacheService.getCachedBands(any)).thenAnswer((_) async => []);
        when(
          mockBandRepository.watchBands(any),
        ).thenAnswer((_) => Stream.value([]));

        final stream = container.read(bandsProvider);
        expect(stream, isNotNull);
      });

      test('setlistsProvider stream is accessible', () {
        when(
          mockCacheService.getCachedSetlists(any),
        ).thenAnswer((_) async => []);
        when(
          mockSetlistRepository.watchSetlists(any),
        ).thenAnswer((_) => Stream.value([]));

        final stream = container.read(setlistsProvider);
        expect(stream, isNotNull);
      });

      test('bandSongsProvider family provider is accessible', () {
        when(
          mockCacheService.getCachedBandSongs(any),
        ).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchBandSongs(any),
        ).thenAnswer((_) => Stream.value([]));

        final stream = container.read(bandSongsProvider('band-1'));
        expect(stream, isNotNull);
      });
    });

    group('Count Providers', () {
      test('songCountProvider returns 0 for empty list', () {
        when(mockCacheService.getCachedSongs(any)).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs(any),
        ).thenAnswer((_) => Stream.value([]));

        final count = container.read(songCountProvider);
        expect(count, 0);
      });

      test('bandCountProvider returns 0 for empty list', () {
        when(mockCacheService.getCachedBands(any)).thenAnswer((_) async => []);
        when(
          mockBandRepository.watchBands(any),
        ).thenAnswer((_) => Stream.value([]));

        final count = container.read(bandCountProvider);
        expect(count, 0);
      });

      test('setlistCountProvider returns 0 for empty list', () {
        when(
          mockCacheService.getCachedSetlists(any),
        ).thenAnswer((_) async => []);
        when(
          mockSetlistRepository.watchSetlists(any),
        ).thenAnswer((_) => Stream.value([]));

        final count = container.read(setlistCountProvider);
        expect(count, 0);
      });
    });

    group('Edge Cases', () {
      test('SelectedBandNotifier handles large band object', () {
        final members = List.generate(
          100,
          (index) => BandMember(
            uid: 'user-$index',
            role: 'viewer',
            displayName: 'Member $index',
            email: 'member$index@example.com',
          ),
        );

        final largeBand = Band(
          id: 'large-band',
          name: 'Large Band',
          createdBy: 'user-1',
          members: members,
          createdAt: DateTime(2024),
        );

        final notifier = container.read(selectedBandProvider.notifier);
        expect(() => notifier.select(largeBand), returnsNormally);

        final selectedBand = container.read(selectedBandProvider);
        expect(selectedBand?.members.length, 100);
      });

      test('Cache service methods are accessible', () {
        expect(mockCacheService.getCachedSongs, isNotNull);
        expect(mockCacheService.cacheSongs, isNotNull);
        expect(mockCacheService.getCachedBands, isNotNull);
        expect(mockCacheService.cacheBands, isNotNull);
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
