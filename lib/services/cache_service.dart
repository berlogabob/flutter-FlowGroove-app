import 'package:hive/hive.dart';
import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';

/// CacheService provides offline-first data persistence using Hive.
///
/// Implements a cache-first strategy:
/// 1. Return cached data immediately
/// 2. Fetch from network in background
/// 3. Update cache and notify listeners
class CacheService {
  static const String _songsBoxPrefix = 'songs_';
  static const String _bandsBoxPrefix = 'bands_';
  static const String _setlistsBoxPrefix = 'setlists_';
  static const String _bandSongsBoxPrefix = 'band_songs_';
  static const String _cacheTimestampKey = 'cache_timestamp';

  /// Opens a Hive box with the given name.
  Future<Box> _openBox(String name) async {
    return await Hive.openBox(name);
  }

  // ============================================================
  // Song Cache Operations (Personal)
  // ============================================================

  /// Caches songs for a specific user.
  Future<void> cacheSongs(String uid, List<Song> songs) async {
    final box = await _openBox('${_songsBoxPrefix}$uid');
    await box.put('songs', songs.map((s) => s.toJson()).toList());
    await box.put(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  /// Retrieves cached songs for a specific user.
  Future<List<Song>> getCachedSongs(String uid) async {
    try {
      final box = await _openBox('${_songsBoxPrefix}$uid');
      final data = box.get('songs', defaultValue: []);
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((j) => Song.fromJson(j))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets the cache timestamp for songs.
  Future<DateTime?> getSongsCacheTimestamp(String uid) async {
    try {
      final box = await _openBox('${_songsBoxPrefix}$uid');
      final timestamp = box.get(_cacheTimestampKey);
      if (timestamp == null) return null;
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Clears cached songs for a user.
  Future<void> clearSongsCache(String uid) async {
    try {
      final box = await _openBox('${_songsBoxPrefix}$uid');
      await box.clear();
      await box.close();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  // ============================================================
  // Band Cache Operations (Personal References)
  // ============================================================

  /// Caches bands for a specific user.
  Future<void> cacheBands(String uid, List<Band> bands) async {
    final box = await _openBox('${_bandsBoxPrefix}$uid');
    await box.put('bands', bands.map((b) => b.toJson()).toList());
    await box.put(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  /// Retrieves cached bands for a specific user.
  Future<List<Band>> getCachedBands(String uid) async {
    try {
      final box = await _openBox('${_bandsBoxPrefix}$uid');
      final data = box.get('bands', defaultValue: []);
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((j) => Band.fromJson(j))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets the cache timestamp for bands.
  Future<DateTime?> getBandsCacheTimestamp(String uid) async {
    try {
      final box = await _openBox('${_bandsBoxPrefix}$uid');
      final timestamp = box.get(_cacheTimestampKey);
      if (timestamp == null) return null;
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Clears cached bands for a user.
  Future<void> clearBandsCache(String uid) async {
    try {
      final box = await _openBox('${_bandsBoxPrefix}$uid');
      await box.clear();
      await box.close();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  // ============================================================
  // Setlist Cache Operations
  // ============================================================

  /// Caches setlists for a specific user.
  Future<void> cacheSetlists(String uid, List<Setlist> setlists) async {
    final box = await _openBox('${_setlistsBoxPrefix}$uid');
    await box.put('setlists', setlists.map((s) => s.toJson()).toList());
    await box.put(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  /// Retrieves cached setlists for a specific user.
  Future<List<Setlist>> getCachedSetlists(String uid) async {
    try {
      final box = await _openBox('${_setlistsBoxPrefix}$uid');
      final data = box.get('setlists', defaultValue: []);
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((j) => Setlist.fromJson(j))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets the cache timestamp for setlists.
  Future<DateTime?> getSetlistsCacheTimestamp(String uid) async {
    try {
      final box = await _openBox('${_setlistsBoxPrefix}$uid');
      final timestamp = box.get(_cacheTimestampKey);
      if (timestamp == null) return null;
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Clears cached setlists for a user.
  Future<void> clearSetlistsCache(String uid) async {
    try {
      final box = await _openBox('${_setlistsBoxPrefix}$uid');
      await box.clear();
      await box.close();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  // ============================================================
  // Band Songs Cache Operations
  // ============================================================

  /// Caches songs for a specific band.
  Future<void> cacheBandSongs(String bandId, List<Song> songs) async {
    final box = await _openBox('${_bandSongsBoxPrefix}$bandId');
    await box.put('songs', songs.map((s) => s.toJson()).toList());
    await box.put(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  /// Retrieves cached songs for a specific band.
  Future<List<Song>> getCachedBandSongs(String bandId) async {
    try {
      final box = await _openBox('${_bandSongsBoxPrefix}$bandId');
      final data = box.get('songs', defaultValue: []);
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((j) => Song.fromJson(j))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Clears cached band songs.
  Future<void> clearBandSongsCache(String bandId) async {
    try {
      final box = await _openBox('${_bandSongsBoxPrefix}$bandId');
      await box.clear();
      await box.close();
    } catch (e) {
      // Ignore errors when clearing cache
    }
  }

  // ============================================================
  // Global Cache Operations
  // ============================================================

  /// Clears all cache for a user (on logout).
  Future<void> clearAllUserCache(String uid) async {
    await clearSongsCache(uid);
    await clearBandsCache(uid);
    await clearSetlistsCache(uid);
    // Also clear any band songs caches for bands this user was part of
    // This is handled by the cache service consumer
  }

  /// Clears all Hive boxes (full reset).
  Future<void> clearAllCache() async {
    await Hive.deleteFromDisk();
  }

  /// Checks if cache exists for a user.
  Future<bool> hasCache(String uid) async {
    // Check if any of the user's cache boxes exist
    // Note: Hive.boxExists returns Future<bool>
    try {
      if (await Hive.boxExists('${_songsBoxPrefix}$uid')) return true;
      if (await Hive.boxExists('${_bandsBoxPrefix}$uid')) return true;
      if (await Hive.boxExists('${_setlistsBoxPrefix}$uid')) return true;
      return false;
    } catch (e) {
      return false;
    }
  }
}
