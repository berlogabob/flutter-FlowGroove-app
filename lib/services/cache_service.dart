import 'package:hive/hive.dart';

/// Clears the legacy per-user Hive data caches on logout.
///
/// The Hive cache-first data layer was removed in #91 (Firestore's built-in
/// offline persistence covers offline reads), so all that remains is deleting
/// the boxes older app versions left on disk.
class CacheService {
  static const _legacyBoxPrefixes = ['songs_', 'bands_', 'setlists_'];

  /// Clears all cached data for a user (on logout).
  Future<void> clearAllUserCache(String uid) async {
    for (final prefix in _legacyBoxPrefixes) {
      try {
        final boxName = '$prefix$uid';
        if (await Hive.boxExists(boxName)) {
          await Hive.deleteBoxFromDisk(boxName);
        }
      } catch (e) {
        // Ignore errors when clearing cache
      }
    }
  }
}
