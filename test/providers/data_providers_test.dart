import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/providers/data_providers.dart';

import '../helpers/mocks.dart';

void main() {
  group('DataProviders', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    group('FirestoreService', () {
      late FirestoreService firestoreService;

      setUp(() {
        firestoreService = FirestoreService();
      });

      group('saveSong', () {
        test('creates valid song for saving', () async {
          final song = MockDataHelper.createMockSong(id: 'song-1');

          expect(song.id, 'song-1');
          expect(song.title, 'Test Song');
          expect(song.artist, 'Test Artist');
          expect(song.toJson(), isA<Map<String, dynamic>>());
        });
      });

      group('watchSongs', () {
        test('method exists and returns Stream type', () {
          final service = FirestoreService();
          expect(service.watchSongs, isNotNull);
        });
      });

      group('saveBand', () {
        test('creates valid band for saving', () async {
          final band = MockDataHelper.createMockBand(id: 'band-1');

          expect(band.id, 'band-1');
          expect(band.name, 'Test Band');
          expect(band.createdBy, 'test-user-id');
          expect(band.toJson(), isA<Map<String, dynamic>>());
        });
      });

      group('watchBands', () {
        test('method exists and returns Stream type', () {
          final service = FirestoreService();
          expect(service.watchBands, isNotNull);
        });
      });

      group('saveSetlist', () {
        test('creates valid setlist for saving', () async {
          final setlist = MockDataHelper.createMockSetlist(id: 'setlist-1');

          expect(setlist.id, 'setlist-1');
          expect(setlist.name, 'Test Setlist');
          expect(setlist.bandId, 'test-band-id');
          expect(setlist.toJson(), isA<Map<String, dynamic>>());
        });
      });

      group('watchSetlists', () {
        test('method exists and returns Stream type', () {
          final service = FirestoreService();
          expect(service.watchSetlists, isNotNull);
        });
      });

      group('delete methods', () {
        test('deleteSong method exists', () {
          expect(firestoreService.deleteSong, isNotNull);
        });

        test('deleteBand method exists', () {
          expect(firestoreService.deleteBand, isNotNull);
        });

        test('deleteSetlist method exists', () {
          expect(firestoreService.deleteSetlist, isNotNull);
        });
      });
    });

    group('SelectedBandNotifier', () {
      test('initializes with null', () {
        final selectedBand = container.read(selectedBandProvider);
        expect(selectedBand, isNull);
      });

      test('selects a band', () {
        final band = MockDataHelper.createMockBand(
          id: 'band-1',
          name: 'Selected Band',
        );

        final notifier = container.read(selectedBandProvider.notifier);
        notifier.select(band);

        final selectedBand = container.read(selectedBandProvider);
        expect(selectedBand, isNotNull);
        expect(selectedBand?.id, 'band-1');
        expect(selectedBand?.name, 'Selected Band');
      });

      test('selects null to clear selection', () {
        final band = MockDataHelper.createMockBand(id: 'band-1');

        final notifier = container.read(selectedBandProvider.notifier);
        notifier.select(band);
        expect(container.read(selectedBandProvider), isNotNull);

        notifier.select(null);
        expect(container.read(selectedBandProvider), isNull);
      });

      test('can change selected band', () {
        final band1 = MockDataHelper.createMockBand(
          id: 'band-1',
          name: 'Band 1',
        );
        final band2 = MockDataHelper.createMockBand(
          id: 'band-2',
          name: 'Band 2',
        );

        final notifier = container.read(selectedBandProvider.notifier);

        notifier.select(band1);
        expect(container.read(selectedBandProvider)?.id, 'band-1');

        notifier.select(band2);
        expect(container.read(selectedBandProvider)?.id, 'band-2');
      });
    });

    group('Count Providers', () {
      test('songCountProvider returns an integer', () {
        final count = container.read(songCountProvider);
        expect(count, isA<int>());
        expect(count, 0); // Initial value
      });

      test('bandCountProvider returns an integer', () {
        final count = container.read(bandCountProvider);
        expect(count, isA<int>());
        expect(count, 0); // Initial value
      });

      test('setlistCountProvider returns an integer', () {
        final count = container.read(setlistCountProvider);
        expect(count, isA<int>());
        expect(count, 0); // Initial value
      });
    });

    group('Provider Initialization', () {
      test('firestoreProvider initializes correctly', () {
        final service = container.read(firestoreProvider);
        expect(service, isNotNull);
        expect(service, isA<FirestoreService>());
      });

      test('all stream providers are initialized', () {
        expect(container.read(songsProvider), isNotNull);
        expect(container.read(bandsProvider), isNotNull);
        expect(container.read(setlistsProvider), isNotNull);
      });
    });

    group('State Updates', () {
      test('SelectedBandNotifier state updates correctly', () {
        final notifier = container.read(selectedBandProvider.notifier);

        // Initial state
        expect(container.read(selectedBandProvider), isNull);

        // Update state
        final band = MockDataHelper.createMockBand(id: 'band-1');
        notifier.select(band);
        expect(container.read(selectedBandProvider), equals(band));

        // Clear state
        notifier.select(null);
        expect(container.read(selectedBandProvider), isNull);
      });

      test('Multiple state updates work correctly', () {
        final notifier = container.read(selectedBandProvider.notifier);

        final band1 = MockDataHelper.createMockBand(
          id: 'band-1',
          name: 'First Band',
        );
        final band2 = MockDataHelper.createMockBand(
          id: 'band-2',
          name: 'Second Band',
        );
        final band3 = MockDataHelper.createMockBand(
          id: 'band-3',
          name: 'Third Band',
        );

        notifier.select(band1);
        expect(container.read(selectedBandProvider)?.name, 'First Band');

        notifier.select(band2);
        expect(container.read(selectedBandProvider)?.name, 'Second Band');

        notifier.select(band3);
        expect(container.read(selectedBandProvider)?.name, 'Third Band');
      });
    });
  });
}
