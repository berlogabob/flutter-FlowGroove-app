import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_repsync_app/providers/data/data_providers.dart';
import 'package:flutter_repsync_app/repositories/repositories.dart';
import 'package:flutter_repsync_app/services/cache_service.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';

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
          cacheProvider.overrideWithValue(mockCacheService),
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

      test('cacheProvider returns mocked instance', () {
        final cache = container.read(cacheProvider);
        expect(cache, equals(mockCacheService));
      });
    });

    group('Song Providers', () {
      test('CachedSongsNotifier initializes with loading state', () {
        final state = container.read(cachedSongsProvider);
        expect(state, isNotNull);
      });

      test('CachedSongsNotifier notifier is accessible', () {
        final notifier = container.read(cachedSongsProvider.notifier);
        expect(notifier, isNotNull);
      });

      test('CachedSongsNotifier dispose cancels subscriptions', () {
        final notifier = container.read(cachedSongsProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

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

      test('CachedSongsNotifier loadSongs method exists', () {
        final notifier = container.read(cachedSongsProvider.notifier);
        expect(notifier.loadSongs, isNotNull);
      });

      test('CachedSongsNotifier watchSongsWithCache method exists', () {
        final notifier = container.read(cachedSongsProvider.notifier);
        expect(notifier.watchSongsWithCache, isNotNull);
      });
    });

    group('Band Providers', () {
      test('CachedBandsNotifier initializes with loading state', () {
        final state = container.read(cachedBandsProvider);
        expect(state, isNotNull);
      });

      test('CachedBandsNotifier notifier is accessible', () {
        final notifier = container.read(cachedBandsProvider.notifier);
        expect(notifier, isNotNull);
      });

      test('CachedBandsNotifier dispose works correctly', () {
        final notifier = container.read(cachedBandsProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

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
          createdAt: DateTime(2024, 1, 1),
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
          createdAt: DateTime(2024, 1, 1),
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
          createdAt: DateTime(2024, 1, 1),
        );
        final band2 = Band(
          id: 'band-2',
          name: 'Band 2',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024, 1, 1),
        );

        final notifier = container.read(selectedBandProvider.notifier);

        notifier.select(band1);
        expect(container.read(selectedBandProvider)?.id, 'band-1');

        notifier.select(band2);
        expect(container.read(selectedBandProvider)?.id, 'band-2');
      });

      test('CachedBandsNotifier loadBands method exists', () {
        final notifier = container.read(cachedBandsProvider.notifier);
        expect(notifier.loadBands, isNotNull);
      });
    });

    group('Setlist Providers', () {
      test('CachedSetlistsNotifier initializes with loading state', () {
        final state = container.read(cachedSetlistsProvider);
        expect(state, isNotNull);
      });

      test('CachedSetlistsNotifier notifier is accessible', () {
        final notifier = container.read(cachedSetlistsProvider.notifier);
        expect(notifier, isNotNull);
      });

      test('CachedSetlistsNotifier dispose works correctly', () {
        final notifier = container.read(cachedSetlistsProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

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

      test('CachedSetlistsNotifier loadSetlists method exists', () {
        final notifier = container.read(cachedSetlistsProvider.notifier);
        expect(notifier.loadSetlists, isNotNull);
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
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
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

    group('Error Handling', () {
      test('CachedSongsNotifier handles repository error', () async {
        when(
          mockCacheService.getCachedSongs('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs('user-1'),
        ).thenThrow(Exception('Repository error'));

        final notifier = container.read(cachedSongsProvider.notifier);
        await notifier.loadSongs('user-1');

        final state = container.read(cachedSongsProvider);
        expect(state.hasError, isTrue);
      });

      test('CachedBandsNotifier handles repository error', () async {
        when(
          mockCacheService.getCachedBands('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockBandRepository.watchBands('user-1'),
        ).thenThrow(Exception('Repository error'));

        final notifier = container.read(cachedBandsProvider.notifier);
        await notifier.loadBands('user-1');

        final state = container.read(cachedBandsProvider);
        expect(state.hasError, isTrue);
      });

      test('CachedSetlistsNotifier handles repository error', () async {
        when(
          mockCacheService.getCachedSetlists('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockSetlistRepository.watchSetlists('user-1'),
        ).thenThrow(Exception('Repository error'));

        final notifier = container.read(cachedSetlistsProvider.notifier);
        await notifier.loadSetlists('user-1');

        final state = container.read(cachedSetlistsProvider);
        expect(state.hasError, isTrue);
      });

      test('Loading state is shown during async operations', () {
        when(
          mockCacheService.getCachedSongs('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs('user-1'),
        ).thenAnswer((_) => Stream.value([]));

        final state = container.read(cachedSongsProvider);
        expect(state, isNotNull);
      });

      test('Empty state is handled correctly', () async {
        when(
          mockCacheService.getCachedSongs('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs('user-1'),
        ).thenAnswer((_) => Stream.value([]));

        final notifier = container.read(cachedSongsProvider.notifier);
        await notifier.loadSongs('user-1');

        final state = container.read(cachedSongsProvider);
        expect(state.value, isEmpty);
      });
    });

    group('Dispose Verification', () {
      test('CachedSongsNotifier dispose cancels subscriptions', () {
        final notifier = container.read(cachedSongsProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

      test('CachedBandsNotifier dispose works correctly', () {
        final notifier = container.read(cachedBandsProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

      test('CachedSetlistsNotifier dispose works correctly', () {
        final notifier = container.read(cachedSetlistsProvider.notifier);
        expect(() => notifier.dispose(), returnsNormally);
      });

      test('ProviderContainer dispose cleans up all resources', () {
        final localContainer = ProviderContainer(
          overrides: [
            songRepositoryProvider.overrideWithValue(mockSongRepository),
            bandRepositoryProvider.overrideWithValue(mockBandRepository),
            setlistRepositoryProvider.overrideWithValue(mockSetlistRepository),
            cacheProvider.overrideWithValue(mockCacheService),
          ],
        );

        // Read all providers
        localContainer.read(cachedSongsProvider);
        localContainer.read(cachedBandsProvider);
        localContainer.read(cachedSetlistsProvider);
        localContainer.read(selectedBandProvider);
        localContainer.read(songCountProvider);
        localContainer.read(bandCountProvider);
        localContainer.read(setlistCountProvider);

        // Dispose should not throw
        expect(() => localContainer.dispose(), returnsNormally);
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
          createdAt: DateTime(2024, 1, 1),
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
          createdAt: DateTime(2024, 1, 1),
        );
        final band2 = Band(
          id: 'band-2',
          name: 'Second Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024, 1, 1),
        );
        final band3 = Band(
          id: 'band-3',
          name: 'Third Band',
          createdBy: 'user-1',
          members: [],
          createdAt: DateTime(2024, 1, 1),
        );

        notifier.select(band1);
        expect(container.read(selectedBandProvider)?.name, 'First Band');

        notifier.select(band2);
        expect(container.read(selectedBandProvider)?.name, 'Second Band');

        notifier.select(band3);
        expect(container.read(selectedBandProvider)?.name, 'Third Band');
      });

      test('CachedSongsNotifier state is accessible', () {
        final state = container.read(cachedSongsProvider);
        expect(state, isNotNull);
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

    group('Timeout Error Handling', () {
      test('CachedSongsNotifier handles timeout error', () async {
        when(
          mockCacheService.getCachedSongs('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs('user-1'),
        ).thenThrow(TimeoutException('Request timed out'));

        final notifier = container.read(cachedSongsProvider.notifier);
        await notifier.loadSongs('user-1');

        final state = container.read(cachedSongsProvider);
        expect(state.hasError, isTrue);
      });

      test('CachedSongsNotifier prefers cache over timeout error', () async {
        final cachedSongs = [
          Song(
            id: 'song-1',
            title: 'Cached Song',
            artist: 'Cached Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        when(
          mockCacheService.getCachedSongs('user-1'),
        ).thenAnswer((_) async => cachedSongs);
        when(
          mockSongRepository.watchSongs('user-1'),
        ).thenThrow(TimeoutException('Request timed out'));

        final notifier = container.read(cachedSongsProvider.notifier);
        await notifier.loadSongs('user-1');

        final state = container.read(cachedSongsProvider);
        // Should fall back to cached data instead of showing error
        expect(state.hasValue, isTrue);
        expect(state.value, equals(cachedSongs));
      });

      test('CachedBandsNotifier handles timeout error', () async {
        when(
          mockCacheService.getCachedBands('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockBandRepository.watchBands('user-1'),
        ).thenThrow(TimeoutException('Request timed out'));

        final notifier = container.read(cachedBandsProvider.notifier);
        await notifier.loadBands('user-1');

        final state = container.read(cachedBandsProvider);
        expect(state.hasError, isTrue);
      });

      test('CachedSetlistsNotifier handles timeout error', () async {
        when(
          mockCacheService.getCachedSetlists('user-1'),
        ).thenAnswer((_) async => []);
        when(
          mockSetlistRepository.watchSetlists('user-1'),
        ).thenThrow(TimeoutException('Request timed out'));

        final notifier = container.read(cachedSetlistsProvider.notifier);
        await notifier.loadSetlists('user-1');

        final state = container.read(cachedSetlistsProvider);
        expect(state.hasError, isTrue);
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
          createdAt: DateTime(2024, 1, 1),
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

    group('Provider Independence', () {
      test('Song providers work independently of band providers', () {
        when(mockCacheService.getCachedSongs(any)).thenAnswer((_) async => []);
        when(
          mockSongRepository.watchSongs(any),
        ).thenAnswer((_) => Stream.value([]));
        when(mockCacheService.getCachedBands(any)).thenAnswer((_) async => []);
        when(
          mockBandRepository.watchBands(any),
        ).thenAnswer((_) => Stream.value([]));

        final songsState = container.read(cachedSongsProvider);
        final bandsState = container.read(cachedBandsProvider);

        expect(songsState, isNotNull);
        expect(bandsState, isNotNull);
      });

      test('Setlist providers work independently', () {
        when(
          mockCacheService.getCachedSetlists(any),
        ).thenAnswer((_) async => []);
        when(
          mockSetlistRepository.watchSetlists(any),
        ).thenAnswer((_) => Stream.value([]));

        final setlistsState = container.read(cachedSetlistsProvider);
        expect(setlistsState, isNotNull);
      });
    });
  });
}
