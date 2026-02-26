import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../models/band.dart';
import '../../models/setlist.dart';
import '../../services/cache_service.dart';
import '../../services/firestore_service.dart';
import '../../repositories/repositories.dart';
import '../auth/auth_provider.dart';

/// Provider for FirestoreService.
final firestoreProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for the SongRepository.
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return FirestoreSongRepository();
});

/// Provider for the BandRepository.
final bandRepositoryProvider = Provider<BandRepository>((ref) {
  return FirestoreBandRepository();
});

/// Provider for the SetlistRepository.
final setlistRepositoryProvider = Provider<SetlistRepository>((ref) {
  return FirestoreSetlistRepository();
});

/// Provider for the CacheService.
final cacheProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Notifier that implements cache-first strategy for songs.
class CachedSongsNotifier extends Notifier<AsyncValue<List<Song>>> {
  StreamSubscription<List<Song>>? _subscription;

  @override
  AsyncValue<List<Song>> build() {
    return const AsyncValue.loading();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Loads songs using cache-first strategy.
  Future<void> loadSongs(String uid) async {
    debugPrint('🔍 [CACHED_SONGS] loadSongs() called for uid: $uid');
    final cache = ref.read(cacheProvider);
    final cachedSongs = await cache.getCachedSongs(uid);

    if (cachedSongs.isNotEmpty) {
      debugPrint('🔍 [CACHED_SONGS] CACHE HIT: ${cachedSongs.length} songs');
      state = AsyncValue.data(cachedSongs);
    } else {
      debugPrint('🔍 [CACHED_SONGS] CACHE MISS, loading...');
      state = const AsyncValue.loading();
    }

    try {
      final songRepo = ref.read(songRepositoryProvider);
      final songs = await songRepo.watchSongs(uid).first;
      await cache.cacheSongs(uid, songs);
      debugPrint('🔍 [CACHED_SONGS] ONLINE: ${songs.length} songs');
      state = AsyncValue.data(songs);
    } catch (e, st) {
      debugPrint('🔍 [CACHED_SONGS] ERROR: $e');
      if (cachedSongs.isNotEmpty) {
        state = AsyncValue.data(cachedSongs);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

/// Provider for songs with cache-first strategy.
final cachedSongsProvider =
    NotifierProvider<CachedSongsNotifier, AsyncValue<List<Song>>>(() {
      return CachedSongsNotifier();
    });

/// Stream provider that watches songs for the current user with caching.
/// 
/// ⚠️ BUG LOCATION: This provider watches currentUserProvider which can be null!
final songsProvider = StreamProvider<List<Song>>((ref) {
  debugPrint('🔍 [SONGS_PROVIDER] Building songsProvider');
  final user = ref.watch(currentUserProvider);
  debugPrint('🔍 [SONGS_PROVIDER] user from currentUserProvider: ${user == null ? 'NULL ⚠️' : user.uid}');
  
  if (user == null) {
    debugPrint('🔍 [SONGS_PROVIDER] ⚠️⚠️⚠️ USER IS NULL - Returning empty stream');
    return Stream.value([]);
  }

  debugPrint('🔍 [SONGS_PROVIDER] user.uid: ${user.uid}');
  final cache = ref.watch(cacheProvider);
  final songRepo = ref.watch(songRepositoryProvider);

  return Stream.multi((listener) {
    bool hasEmittedCache = false;

    cache.getCachedSongs(user.uid).then((cachedSongs) {
      debugPrint('🔍 [SONGS_PROVIDER] Cached songs: ${cachedSongs.length}');
      if (cachedSongs.isNotEmpty && !listener.isClosed) {
        listener.add(cachedSongs);
        hasEmittedCache = true;
      }
    });

    final subscription = songRepo
        .watchSongs(user.uid)
        .listen(
          (songs) async {
            await cache.cacheSongs(user.uid, songs);
            if (!listener.isClosed) {
              listener.add(songs);
            }
          },
          onError: (error) {
            debugPrint('🔍 [SONGS_PROVIDER] Stream error: $error');
            if (!hasEmittedCache && !listener.isClosed) {
              cache.getCachedSongs(user.uid).then((cachedSongs) {
                if (!listener.isClosed) {
                  listener.add(cachedSongs);
                }
              });
            }
          },
        );

    listener.onCancel = () {
      subscription.cancel();
    };
  });
});

/// Notifier for the currently selected band.
class SelectedBandNotifier extends Notifier<Band?> {
  @override
  Band? build() => null;

  void select(Band? band) {
    state = band;
  }
}

/// Provider for the selected band state.
final selectedBandProvider = NotifierProvider<SelectedBandNotifier, Band?>(() {
  return SelectedBandNotifier();
});

/// Notifier that implements cache-first strategy for bands.
class CachedBandsNotifier extends Notifier<AsyncValue<List<Band>>> {
  @override
  AsyncValue<List<Band>> build() {
    return const AsyncValue.loading();
  }

  @override
  void dispose() {
    // No stream subscriptions to cancel
  }

  /// Loads bands using cache-first strategy.
  Future<void> loadBands(String uid) async {
    debugPrint('🔍 [CACHED_BANDS] loadBands() called for uid: $uid');
    final cache = ref.read(cacheProvider);
    final cachedBands = await cache.getCachedBands(uid);

    if (cachedBands.isNotEmpty) {
      state = AsyncValue.data(cachedBands);
    } else {
      state = const AsyncValue.loading();
    }

    try {
      final bandRepo = ref.read(bandRepositoryProvider);
      final bands = await bandRepo.watchBands(uid).first;
      await cache.cacheBands(uid, bands);
      state = AsyncValue.data(bands);
    } catch (e, st) {
      if (cachedBands.isNotEmpty) {
        state = AsyncValue.data(cachedBands);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

/// Provider for bands with cache-first strategy.
final cachedBandsProvider =
    NotifierProvider<CachedBandsNotifier, AsyncValue<List<Band>>>(() {
      return CachedBandsNotifier();
    });

/// Stream provider that watches bands for the current user with caching.
/// 
/// ⚠️ BUG LOCATION: This provider watches currentUserProvider which can be null!
final bandsProvider = StreamProvider<List<Band>>((ref) {
  debugPrint('🔍 [BANDS_PROVIDER] Building bandsProvider');
  final user = ref.watch(currentUserProvider);
  debugPrint('🔍 [BANDS_PROVIDER] user from currentUserProvider: ${user == null ? 'NULL ⚠️' : user.uid}');
  
  if (user == null) {
    debugPrint('🔍 [BANDS_PROVIDER] ⚠️⚠️⚠️ USER IS NULL - Returning empty stream');
    return Stream.value([]);
  }

  debugPrint('🔍 [BANDS_PROVIDER] user.uid: ${user.uid}');
  final cache = ref.watch(cacheProvider);
  final bandRepo = ref.watch(bandRepositoryProvider);

  return Stream.multi((listener) {
    bool hasEmittedCache = false;

    cache.getCachedBands(user.uid).then((cachedBands) {
      if (cachedBands.isNotEmpty && !listener.isClosed) {
        listener.add(cachedBands);
        hasEmittedCache = true;
      }
    });

    final subscription = bandRepo
        .watchBands(user.uid)
        .listen(
          (bands) async {
            await cache.cacheBands(user.uid, bands);
            if (!listener.isClosed) {
              listener.add(bands);
            }
          },
          onError: (error) {
            if (!hasEmittedCache && !listener.isClosed) {
              cache.getCachedBands(user.uid).then((cachedBands) {
                if (!listener.isClosed) {
                  listener.add(cachedBands);
                }
              });
            }
          },
        );

    listener.onCancel = () {
      subscription.cancel();
    };
  });
});

/// Notifier that implements cache-first strategy for setlists.
class CachedSetlistsNotifier extends Notifier<AsyncValue<List<Setlist>>> {
  @override
  AsyncValue<List<Setlist>> build() {
    return const AsyncValue.loading();
  }

  @override
  void dispose() {
    // No stream subscriptions to cancel
  }

  /// Loads setlists using cache-first strategy.
  Future<void> loadSetlists(String uid) async {
    debugPrint('🔍 [CACHED_SETLISTS] loadSetlists() called for uid: $uid');
    final cache = ref.read(cacheProvider);
    final cachedSetlists = await cache.getCachedSetlists(uid);

    if (cachedSetlists.isNotEmpty) {
      state = AsyncValue.data(cachedSetlists);
    } else {
      state = const AsyncValue.loading();
    }

    try {
      final setlistRepo = ref.read(setlistRepositoryProvider);
      final setlists = await setlistRepo.watchSetlists(uid).first;
      await cache.cacheSetlists(uid, setlists);
      state = AsyncValue.data(setlists);
    } catch (e, st) {
      if (cachedSetlists.isNotEmpty) {
        state = AsyncValue.data(cachedSetlists);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

/// Provider for setlists with cache-first strategy.
final cachedSetlistsProvider =
    NotifierProvider<CachedSetlistsNotifier, AsyncValue<List<Setlist>>>(() {
      return CachedSetlistsNotifier();
    });

/// Stream provider that watches setlists for the current user with caching.
/// 
/// ⚠️ BUG LOCATION: This provider watches currentUserProvider which can be null!
final setlistsProvider = StreamProvider<List<Setlist>>((ref) {
  debugPrint('🔍 [SETLISTS_PROVIDER] Building setlistsProvider');
  final user = ref.watch(currentUserProvider);
  debugPrint('🔍 [SETLISTS_PROVIDER] user from currentUserProvider: ${user == null ? 'NULL ⚠️' : user.uid}');
  
  if (user == null) {
    debugPrint('🔍 [SETLISTS_PROVIDER] ⚠️⚠️⚠️ USER IS NULL - Returning empty stream');
    return Stream.value([]);
  }

  debugPrint('🔍 [SETLISTS_PROVIDER] user.uid: ${user.uid}');
  final cache = ref.watch(cacheProvider);
  final setlistRepo = ref.watch(setlistRepositoryProvider);

  return Stream.multi((listener) {
    bool hasEmittedCache = false;

    cache.getCachedSetlists(user.uid).then((cachedSetlists) {
      if (cachedSetlists.isNotEmpty && !listener.isClosed) {
        listener.add(cachedSetlists);
        hasEmittedCache = true;
      }
    });

    final subscription = setlistRepo
        .watchSetlists(user.uid)
        .listen(
          (setlists) async {
            await cache.cacheSetlists(user.uid, setlists);
            if (!listener.isClosed) {
              listener.add(setlists);
            }
          },
          onError: (error) {
            if (!hasEmittedCache && !listener.isClosed) {
              cache.getCachedSetlists(user.uid).then((cachedSetlists) {
                if (!listener.isClosed) {
                  listener.add(cachedSetlists);
                }
              });
            }
          },
        );

    listener.onCancel = () {
      subscription.cancel();
    };
  });
});

/// Stream provider that watches band songs with caching.
final bandSongsProvider = StreamProvider.family<List<Song>, String>((
  ref,
  bandId,
) {
  final cache = ref.watch(cacheProvider);
  final songRepo = ref.watch(songRepositoryProvider);

  return Stream.multi((listener) {
    bool hasEmittedCache = false;

    cache.getCachedBandSongs(bandId).then((cachedSongs) {
      if (cachedSongs.isNotEmpty && !listener.isClosed) {
        listener.add(cachedSongs);
        hasEmittedCache = true;
      }
    });

    final subscription = songRepo
        .watchBandSongs(bandId)
        .listen(
          (songs) async {
            await cache.cacheBandSongs(bandId, songs);
            if (!listener.isClosed) {
              listener.add(songs);
            }
          },
          onError: (error) {
            if (!hasEmittedCache && !listener.isClosed) {
              cache.getCachedBandSongs(bandId).then((cachedSongs) {
                if (!listener.isClosed) {
                  listener.add(cachedSongs);
                }
              });
            }
          },
        );

    listener.onCancel = () {
      subscription.cancel();
    };
  });
});

/// Provider that returns the count of songs.
final songCountProvider = Provider<int>((ref) {
  debugPrint('🔍 [SONG_COUNT] Building songCountProvider');
  final songsAsync = ref.watch(songsProvider);
  final count = songsAsync.whenOrNull(data: (songs) => songs.length) ?? 0;
  debugPrint('🔍 [SONG_COUNT] Song count: $count');
  return count;
});

/// Provider that returns the count of bands.
final bandCountProvider = Provider<int>((ref) {
  debugPrint('🔍 [BAND_COUNT] Building bandCountProvider');
  final bandsAsync = ref.watch(bandsProvider);
  final count = bandsAsync.whenOrNull(data: (bands) => bands.length) ?? 0;
  debugPrint('🔍 [BAND_COUNT] Band count: $count');
  return count;
});

/// Provider that returns the count of setlists.
final setlistCountProvider = Provider<int>((ref) {
  debugPrint('🔍 [SETLIST_COUNT] Building setlistCountProvider');
  final setlistsAsync = ref.watch(setlistsProvider);
  final count = setlistsAsync.whenOrNull(data: (setlists) => setlists.length) ?? 0;
  debugPrint('🔍 [SETLIST_COUNT] Setlist count: $count');
  return count;
});
