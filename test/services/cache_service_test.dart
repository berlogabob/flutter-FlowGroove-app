import 'package:flowgroove/services/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('CacheService', () {
    late CacheService cacheService;
    const testUid = 'test-user-123';

    setUp(() async {
      cacheService = CacheService();
      Hive.init('test_hive');
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    test('clearAllUserCache deletes legacy per-user boxes', () async {
      for (final prefix in ['songs_', 'bands_', 'setlists_']) {
        final box = await Hive.openBox<dynamic>('$prefix$testUid');
        await box.put('data', ['legacy']);
        await box.close();
      }

      await cacheService.clearAllUserCache(testUid);

      expect(await Hive.boxExists('songs_$testUid'), isFalse);
      expect(await Hive.boxExists('bands_$testUid'), isFalse);
      expect(await Hive.boxExists('setlists_$testUid'), isFalse);
    });

    test('clearAllUserCache leaves other users\' boxes alone', () async {
      final box = await Hive.openBox<dynamic>('songs_other-user');
      await box.put('data', ['keep']);
      await box.close();

      await cacheService.clearAllUserCache(testUid);

      expect(await Hive.boxExists('songs_other-user'), isTrue);
    });

    test('clearAllUserCache is a no-op when no boxes exist', () async {
      await expectLater(
        cacheService.clearAllUserCache('non-existent-user'),
        completes,
      );
    });
  });
}
