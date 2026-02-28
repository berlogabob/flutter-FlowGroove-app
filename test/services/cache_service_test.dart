import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_repsync_app/services/cache_service.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/link.dart';

void main() {
  group('CacheService', () {
    late CacheService cacheService;
    const testUid = 'test-user-123';
    const testBandId = 'test-band-456';

    setUp(() async {
      cacheService = CacheService();
      // Initialize Hive for testing
      Hive.init('test_hive');
    });

    tearDown(() async {
      // Clean up all boxes after each test
      await Hive.deleteFromDisk();
    });

    group('Song Cache Operations', () {
      test('cacheSongs stores songs for user', () async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Test Song 1',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          Song(
            id: 'song-2',
            title: 'Test Song 2',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSongs(testUid, songs);

        final cachedSongs = await cacheService.getCachedSongs(testUid);
        expect(cachedSongs.length, equals(2));
        expect(cachedSongs[0].id, equals('song-1'));
        expect(cachedSongs[1].id, equals('song-2'));
      });

      test('getCachedSongs returns empty list when no cache', () async {
        final songs = await cacheService.getCachedSongs('non-existent-user');
        expect(songs, isEmpty);
      });

      test('cacheSongs overwrites existing cache', () async {
        final songs1 = [
          Song(
            id: 'song-1',
            title: 'Original Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSongs(testUid, songs1);

        final songs2 = [
          Song(
            id: 'song-2',
            title: 'New Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSongs(testUid, songs2);

        final cachedSongs = await cacheService.getCachedSongs(testUid);
        expect(cachedSongs.length, equals(1));
        expect(cachedSongs[0].id, equals('song-2'));
      });

      test('getSongsCacheTimestamp returns timestamp after caching', () async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        final beforeCache = await cacheService.getSongsCacheTimestamp(testUid);
        expect(beforeCache, isNull);

        await cacheService.cacheSongs(testUid, songs);

        final afterCache = await cacheService.getSongsCacheTimestamp(testUid);
        expect(afterCache, isNotNull);
        expect(afterCache, isA<DateTime>());
      });

      test('getSongsCacheTimestamp returns null when no cache', () async {
        final timestamp = await cacheService.getSongsCacheTimestamp(testUid);
        expect(timestamp, isNull);
      });

      test('clearSongsCache removes cached songs', () async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSongs(testUid, songs);
        await cacheService.clearSongsCache(testUid);

        final cachedSongs = await cacheService.getCachedSongs(testUid);
        expect(cachedSongs, isEmpty);
      });

      test('cacheSongs preserves song data correctly', () async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            originalKey: 'C',
            originalBPM: 120,
            ourKey: 'D',
            ourBPM: 130,
            links: [Link(url: 'https://example.com', type: 'youtube')],
            notes: 'Test Notes',
            tags: ['rock', 'classic'],
            bandId: 'band-1',
            spotifyUrl: 'https://spotify.com/track/123',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSongs(testUid, songs);

        final cachedSongs = await cacheService.getCachedSongs(testUid);
        expect(cachedSongs.length, equals(1));
        expect(cachedSongs[0].title, equals('Test Song'));
        expect(cachedSongs[0].originalKey, equals('C'));
        expect(cachedSongs[0].originalBPM, equals(120));
        expect(cachedSongs[0].ourKey, equals('D'));
        expect(cachedSongs[0].ourBPM, equals(130));
        expect(cachedSongs[0].notes, equals('Test Notes'));
        expect(cachedSongs[0].tags.length, equals(2));
      });
    });

    group('Band Cache Operations', () {
      test('cacheBands stores bands for user', () async {
        final bands = [
          Band(
            id: 'band-1',
            name: 'Test Band 1',
            createdBy: testUid,
            createdAt: DateTime(2024, 1, 1),
          ),
          Band(
            id: 'band-2',
            name: 'Test Band 2',
            createdBy: testUid,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheBands(testUid, bands);

        final cachedBands = await cacheService.getCachedBands(testUid);
        expect(cachedBands.length, equals(2));
        expect(cachedBands[0].id, equals('band-1'));
        expect(cachedBands[1].id, equals('band-2'));
      });

      test('getCachedBands returns empty list when no cache', () async {
        final bands = await cacheService.getCachedBands('non-existent-user');
        expect(bands, isEmpty);
      });

      test('getBandsCacheTimestamp returns timestamp after caching', () async {
        final bands = [
          Band(
            id: 'band-1',
            name: 'Test Band',
            createdBy: testUid,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        final beforeCache = await cacheService.getBandsCacheTimestamp(testUid);
        expect(beforeCache, isNull);

        await cacheService.cacheBands(testUid, bands);

        final afterCache = await cacheService.getBandsCacheTimestamp(testUid);
        expect(afterCache, isNotNull);
      });

      test('clearBandsCache removes cached bands', () async {
        final bands = [
          Band(
            id: 'band-1',
            name: 'Test Band',
            createdBy: testUid,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheBands(testUid, bands);
        await cacheService.clearBandsCache(testUid);

        final cachedBands = await cacheService.getCachedBands(testUid);
        expect(cachedBands, isEmpty);
      });

      test('cacheBands preserves band data correctly', () async {
        final bands = [
          Band(
            id: 'band-1',
            name: 'Test Band',
            description: 'Test Description',
            createdBy: testUid,
            inviteCode: 'ABC123',
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheBands(testUid, bands);

        final cachedBands = await cacheService.getCachedBands(testUid);
        expect(cachedBands.length, equals(1));
        expect(cachedBands[0].name, equals('Test Band'));
        expect(cachedBands[0].description, equals('Test Description'));
        expect(cachedBands[0].inviteCode, equals('ABC123'));
      });
    });

    group('Setlist Cache Operations', () {
      test('cacheSetlists stores setlists for user', () async {
        final setlists = [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Test Setlist 1',
            songIds: ['song-1', 'song-2'],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          Setlist(
            id: 'setlist-2',
            bandId: 'band-1',
            name: 'Test Setlist 2',
            songIds: ['song-3'],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSetlists(testUid, setlists);

        final cachedSetlists = await cacheService.getCachedSetlists(testUid);
        expect(cachedSetlists.length, equals(2));
        expect(cachedSetlists[0].id, equals('setlist-1'));
        expect(cachedSetlists[1].id, equals('setlist-2'));
      });

      test('getCachedSetlists returns empty list when no cache', () async {
        final setlists = await cacheService.getCachedSetlists(
          'non-existent-user',
        );
        expect(setlists, isEmpty);
      });

      test(
        'getSetlistsCacheTimestamp returns timestamp after caching',
        () async {
          final setlists = [
            Setlist(
              id: 'setlist-1',
              bandId: 'band-1',
              name: 'Test Setlist',
              songIds: [],
              createdAt: DateTime(2024, 1, 1),
              updatedAt: DateTime(2024, 1, 1),
            ),
          ];

          final beforeCache = await cacheService.getSetlistsCacheTimestamp(
            testUid,
          );
          expect(beforeCache, isNull);

          await cacheService.cacheSetlists(testUid, setlists);

          final afterCache = await cacheService.getSetlistsCacheTimestamp(
            testUid,
          );
          expect(afterCache, isNotNull);
        },
      );

      test('clearSetlistsCache removes cached setlists', () async {
        final setlists = [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Test Setlist',
            songIds: [],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSetlists(testUid, setlists);
        await cacheService.clearSetlistsCache(testUid);

        final cachedSetlists = await cacheService.getCachedSetlists(testUid);
        expect(cachedSetlists, isEmpty);
      });

      test('cacheSetlists preserves setlist data correctly', () async {
        final setlists = [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Test Setlist',
            description: 'Test Description',
            eventDate: DateTime(2024, 12, 25),
            eventLocation: 'Test Venue',
            songIds: ['song-1', 'song-2'],
            totalDuration: 600,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSetlists(testUid, setlists);

        final cachedSetlists = await cacheService.getCachedSetlists(testUid);
        expect(cachedSetlists.length, equals(1));
        expect(cachedSetlists[0].name, equals('Test Setlist'));
        expect(cachedSetlists[0].description, equals('Test Description'));
        expect(cachedSetlists[0].eventDate, equals(DateTime(2024, 12, 25)));
        expect(cachedSetlists[0].eventLocation, equals('Test Venue'));
        expect(cachedSetlists[0].songIds.length, equals(2));
      });
    });

    group('Band Songs Cache Operations', () {
      test('cacheBandSongs stores songs for band', () async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Band Song 1',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheBandSongs(testBandId, songs);

        final cachedSongs = await cacheService.getCachedBandSongs(testBandId);
        expect(cachedSongs.length, equals(1));
        expect(cachedSongs[0].id, equals('song-1'));
      });

      test('getCachedBandSongs returns empty list when no cache', () async {
        final songs = await cacheService.getCachedBandSongs(
          'non-existent-band',
        );
        expect(songs, isEmpty);
      });

      test('clearBandSongsCache removes cached band songs', () async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Band Song',
            artist: 'Test Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheBandSongs(testBandId, songs);
        await cacheService.clearBandSongsCache(testBandId);

        final cachedSongs = await cacheService.getCachedBandSongs(testBandId);
        expect(cachedSongs, isEmpty);
      });
    });

    group('Global Cache Operations', () {
      test('clearAllUserCache clears all user caches', () async {
        // Cache data for user
        await cacheService.cacheSongs(testUid, [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ]);

        await cacheService.cacheBands(testUid, [
          Band(
            id: 'band-1',
            name: 'Test Band',
            createdBy: testUid,
            createdAt: DateTime(2024, 1, 1),
          ),
        ]);

        await cacheService.cacheSetlists(testUid, [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Test Setlist',
            songIds: [],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ]);

        await cacheService.clearAllUserCache(testUid);

        expect(await cacheService.getCachedSongs(testUid), isEmpty);
        expect(await cacheService.getCachedBands(testUid), isEmpty);
        expect(await cacheService.getCachedSetlists(testUid), isEmpty);
      });

      test('clearAllCache clears all Hive data', () async {
        // Cache data for multiple users
        await cacheService.cacheSongs(testUid, [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ]);

        await cacheService.cacheSongs('other-user', [
          Song(
            id: 'song-2',
            title: 'Other Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ]);

        await cacheService.clearAllCache();

        expect(await cacheService.getCachedSongs(testUid), isEmpty);
        expect(await cacheService.getCachedSongs('other-user'), isEmpty);
      });

      test('hasCache returns true when cache exists', () async {
        await cacheService.cacheSongs(testUid, [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ]);

        final hasCache = await cacheService.hasCache(testUid);
        expect(hasCache, isTrue);
      });

      test('hasCache returns false when no cache exists', () async {
        final hasCache = await cacheService.hasCache('non-existent-user');
        expect(hasCache, isFalse);
      });

      test('hasCache returns false after clearing cache', () async {
        await cacheService.cacheSongs(testUid, [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ]);

        await cacheService.clearSongsCache(testUid);

        final hasCache = await cacheService.hasCache(testUid);
        expect(hasCache, isFalse);
      });
    });

    group('Error Handling', () {
      test('getCachedSongs handles corrupted data gracefully', () async {
        // Manually put invalid data in the box
        final box = await Hive.openBox('songs_$testUid');
        await box.put('songs', 'invalid-data');

        final songs = await cacheService.getCachedSongs(testUid);
        expect(songs, isEmpty);
      });

      test('getCachedBands handles corrupted data gracefully', () async {
        final box = await Hive.openBox('bands_$testUid');
        await box.put('bands', 'invalid-data');

        final bands = await cacheService.getCachedBands(testUid);
        expect(bands, isEmpty);
      });

      test('getCachedSetlists handles corrupted data gracefully', () async {
        final box = await Hive.openBox('setlists_$testUid');
        await box.put('setlists', 'invalid-data');

        final setlists = await cacheService.getCachedSetlists(testUid);
        expect(setlists, isEmpty);
      });

      test('getCachedBandSongs handles corrupted data gracefully', () async {
        final box = await Hive.openBox('band_songs_$testBandId');
        await box.put('songs', 'invalid-data');

        final songs = await cacheService.getCachedBandSongs(testBandId);
        expect(songs, isEmpty);
      });

      test('clearSongsCache handles errors gracefully', () async {
        // Should not throw exception
        await cacheService.clearSongsCache('non-existent-user');
        expect(true, isTrue);
      });

      test('clearBandsCache handles errors gracefully', () async {
        await cacheService.clearBandsCache('non-existent-user');
        expect(true, isTrue);
      });

      test('clearSetlistsCache handles errors gracefully', () async {
        await cacheService.clearSetlistsCache('non-existent-user');
        expect(true, isTrue);
      });

      test('clearBandSongsCache handles errors gracefully', () async {
        await cacheService.clearBandSongsCache('non-existent-band');
        expect(true, isTrue);
      });

      test('hasCache handles errors gracefully', () async {
        final hasCache = await cacheService.hasCache('invalid-user');
        expect(hasCache, isFalse);
      });
    });

    group('Edge Cases', () {
      test('cacheSongs with empty list', () async {
        await cacheService.cacheSongs(testUid, []);

        final cachedSongs = await cacheService.getCachedSongs(testUid);
        expect(cachedSongs, isEmpty);
      });

      test('cacheBands with empty list', () async {
        await cacheService.cacheBands(testUid, []);

        final cachedBands = await cacheService.getCachedBands(testUid);
        expect(cachedBands, isEmpty);
      });

      test('cacheSetlists with empty list', () async {
        await cacheService.cacheSetlists(testUid, []);

        final cachedSetlists = await cacheService.getCachedSetlists(testUid);
        expect(cachedSetlists, isEmpty);
      });

      test('cacheBandSongs with empty list', () async {
        await cacheService.cacheBandSongs(testBandId, []);

        final cachedSongs = await cacheService.getCachedBandSongs(testBandId);
        expect(cachedSongs, isEmpty);
      });

      test('different users have separate caches', () async {
        final user1Songs = [
          Song(
            id: 'song-1',
            title: 'User 1 Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        final user2Songs = [
          Song(
            id: 'song-2',
            title: 'User 2 Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheSongs('user-1', user1Songs);
        await cacheService.cacheSongs('user-2', user2Songs);

        final user1Cached = await cacheService.getCachedSongs('user-1');
        final user2Cached = await cacheService.getCachedSongs('user-2');

        expect(user1Cached.length, equals(1));
        expect(user1Cached[0].title, equals('User 1 Song'));

        expect(user2Cached.length, equals(1));
        expect(user2Cached[0].title, equals('User 2 Song'));
      });

      test('different bands have separate caches', () async {
        final band1Songs = [
          Song(
            id: 'song-1',
            title: 'Band 1 Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        final band2Songs = [
          Song(
            id: 'song-2',
            title: 'Band 2 Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await cacheService.cacheBandSongs('band-1', band1Songs);
        await cacheService.cacheBandSongs('band-2', band2Songs);

        final band1Cached = await cacheService.getCachedBandSongs('band-1');
        final band2Cached = await cacheService.getCachedBandSongs('band-2');

        expect(band1Cached.length, equals(1));
        expect(band1Cached[0].title, equals('Band 1 Song'));

        expect(band2Cached.length, equals(1));
        expect(band2Cached[0].title, equals('Band 2 Song'));
      });
    });
  });
}
