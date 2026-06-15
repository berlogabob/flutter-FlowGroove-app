import 'package:hive/hive.dart';

import '../models/band.dart';
import '../models/setlist.dart';
import '../models/song.dart';

/// CacheService provides offline-first data persistence using Hive.
///
/// Implements a cache-first strategy with TTL:
/// 1. Return cached data immediately (even if stale)
/// 2. Caller checks isCacheStale() to decide on background refresh
/// 3. Fetch from network in background
/// 4. Update cache and notify listeners
///
/// Default TTLs:
/// - Songs/Bands/Setlists: 24 hours
/// - Band songs: 12 hours (shared data changes more frequently)
class CacheService {
  static const String _songsBoxPrefix = 'songs_';
  static const String _bandsBoxPrefix = 'bands_';
  static const String _setlistsBoxPrefix = 'setlists_';
  static const String _bandSongsBoxPrefix = 'band_songs_';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const String _cacheDataKey = 'data';

  /// Default cache TTLs
  static const defaultTtl = Duration(hours: 24);
  static const bandSongsTtl = Duration(hours: 12);

  /// Check if cache is stale for a given box.
  Future<bool> isCacheStale(String boxName, {Duration? ttl}) async {
    try {
      final box = await _openBox(boxName);
      final timestamp = box.get(_cacheTimestampKey);
      if (timestamp == null) return true; // No timestamp = stale

      final cachedAt = DateTime.parse(timestamp as String);
      final age = DateTime.now().difference(cachedAt);
      final effectiveTtl = ttl ?? defaultTtl;
      return age > effectiveTtl;
    } catch (e) {
      return true; // Error = treat as stale
    }
  }

  /// Opens a Hive box with the given name.
  Future<Box> _openBox(String name) async {
    return Hive.openBox(name);
  }

  /// Generic method to cache a list of items.
  Future<void> _cacheItems<T>({
    required String boxName,
    required List<T> items,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    final box = await _openBox(boxName);
    await box.put(_cacheDataKey, items.map(toJson).toList());
    await box.put(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  /// Generic method to retrieve cached items.
  Future<List<T>> _getCachedItems<T>({
    required String boxName,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final box = await _openBox(boxName);
      final data = box.get(_cacheDataKey, defaultValue: []);
      if (data is! List) return [];
      return data.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (e) {
      return [];
    }
  }

  /// Generic method to get cache timestamp.
  Future<DateTime?> _getCacheTimestamp(String boxName) async {
    try {
      final box = await _openBox(boxName);
      final timestamp = box.get(_cacheTimestampKey);
      if (timestamp == null) return null;
      return DateTime.parse(timestamp as String);
    } catch (e) {
      return null;
    }
  }

  /// Generic method to clear cache for a box.
  Future<void> _clearCache(String boxName) async {
    try {
      final box = await _openBox(boxName);
      await box.clear();
      await box.close();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  // ============================================================
  // Song Cache Operations (Personal)
  // ============================================================

  /// Caches songs for a specific user.
  Future<void> cacheSongs(String uid, List<Song> songs) => _cacheItems(
    boxName: '$_songsBoxPrefix$uid',
    items: songs,
    toJson: (song) => song.toJson(),
  );

  /// Retrieves cached songs for a specific user.
  Future<List<Song>> getCachedSongs(String uid) => _getCachedItems(
    boxName: '$_songsBoxPrefix$uid',
    fromJson: Song.fromJson,
  );

  /// Gets the cache timestamp for songs.
  Future<DateTime?> getSongsCacheTimestamp(String uid) =>
      _getCacheTimestamp('$_songsBoxPrefix$uid');

  /// Clears cached songs for a user.
  Future<void> clearSongsCache(String uid) =>
      _clearCache('$_songsBoxPrefix$uid');

  // ============================================================
  // Band Cache Operations (Personal References)
  // ============================================================

  /// Caches bands for a specific user.
  Future<void> cacheBands(String uid, List<Band> bands) => _cacheItems(
    boxName: '$_bandsBoxPrefix$uid',
    items: bands,
    toJson: (band) => band.toJson(),
  );

  /// Retrieves cached bands for a specific user.
  Future<List<Band>> getCachedBands(String uid) => _getCachedItems(
    boxName: '$_bandsBoxPrefix$uid',
    fromJson: Band.fromJson,
  );

  /// Gets the cache timestamp for bands.
  Future<DateTime?> getBandsCacheTimestamp(String uid) =>
      _getCacheTimestamp('$_bandsBoxPrefix$uid');

  /// Clears cached bands for a user.
  Future<void> clearBandsCache(String uid) =>
      _clearCache('$_bandsBoxPrefix$uid');

  // ============================================================
  // Setlist Cache Operations
  // ============================================================

  /// Caches setlists for a specific user.
  Future<void> cacheSetlists(String uid, List<Setlist> setlists) => _cacheItems(
    boxName: '$_setlistsBoxPrefix$uid',
    items: setlists,
    toJson: (setlist) => setlist.toJson(),
  );

  /// Retrieves cached setlists for a specific user.
  Future<List<Setlist>> getCachedSetlists(String uid) => _getCachedItems(
    boxName: '$_setlistsBoxPrefix$uid',
    fromJson: Setlist.fromJson,
  );

  /// Gets the cache timestamp for setlists.
  Future<DateTime?> getSetlistsCacheTimestamp(String uid) =>
      _getCacheTimestamp('$_setlistsBoxPrefix$uid');

  /// Clears cached setlists for a user.
  Future<void> clearSetlistsCache(String uid) async {
    final boxName = '$_setlistsBoxPrefix$uid';
    if (await Hive.boxExists(boxName)) {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }

  // ============================================================
  // Band Songs Cache Operations
  // ============================================================

  /// Caches songs for a specific band.
  Future<void> cacheBandSongs(String bandId, List<Song> songs) => _cacheItems(
    boxName: '$_bandSongsBoxPrefix$bandId',
    items: songs,
    toJson: (song) => song.toJson(),
  );

  /// Retrieves cached songs for a specific band.
  Future<List<Song>> getCachedBandSongs(String bandId) => _getCachedItems(
    boxName: '$_bandSongsBoxPrefix$bandId',
    fromJson: Song.fromJson,
  );

  /// Clears cached band songs.
  Future<void> clearBandSongsCache(String bandId) =>
      _clearCache('$_bandSongsBoxPrefix$bandId');

  // ============================================================
  // Global Cache Operations
  // ============================================================

  /// Clears all cache for a user (on logout).
  Future<void> clearAllUserCache(String uid) async {
    await clearSongsCache(uid);
    await clearBandsCache(uid);
    await clearSetlistsCache(uid);
  }

  /// Clears all Hive boxes (full reset).
  Future<void> clearAllCache() async {
    await Hive.deleteFromDisk();
  }

  /// Checks if cache exists for a user.
  Future<bool> hasCache(String uid) async {
    try {
      if (await _boxHasCache('$_songsBoxPrefix$uid')) return true;
      if (await _boxHasCache('$_bandsBoxPrefix$uid')) return true;
      if (await _boxHasCache('$_setlistsBoxPrefix$uid')) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _boxHasCache(String boxName) async {
    if (!await Hive.boxExists(boxName)) return false;
    final box = await _openBox(boxName);
    return box.containsKey(_cacheDataKey) ||
        box.containsKey(_cacheTimestampKey);
  }
}
