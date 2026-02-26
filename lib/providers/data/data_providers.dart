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
///
/// Usage:
/// ```dart
/// final firestore = ref.read(firestoreProvider);
/// await firestore.saveSong(song, uid: uid);
/// ```
final firestoreProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for the SongRepository.
///
/// Usage:
/// ```dart
/// final songRepo = ref.read(songRepositoryProvider);
/// await songRepo.saveSong(song, uid);
/// ```
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return FirestoreSongRepository();
});

/// Provider for the BandRepository.
///
/// Usage:
/// ```dart
/// final bandRepo = ref.read(bandRepositoryProvider);
/// await bandRepo.saveBand(band, uid);
/// ```
final bandRepositoryProvider = Provider<BandRepository>((ref) {
  return FirestoreBandRepository();
});

/// Provider for the SetlistRepository.
///
/// Usage:
/// ```dart
/// final setlistRepo = ref.read(setlistRepositoryProvider);
/// await setlistRepo.saveSetlist(setlist, uid);
/// ```
final setlistRepositoryProvider = Provider<SetlistRepository>((ref) {
  return FirestoreSetlistRepository();
});

/// Provider for the CacheService.
///
/// Usage:
/// ```dart
/// final cache = ref.read(cacheProvider);
/// await cache.cacheSongs(uid, songs);
/// ```
final cacheProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Notifier that implements cache-first strategy for songs.
///
/// Strategy:
/// 1. Return cached data immediately
/// 2. Fetch from network in background
/// 3. Update cache and notify listeners
///
/// IMPORTANT: Properly disposes stream subscriptions to prevent memory leaks.
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
    // Step 1: Return cached data immediately
    final cache = ref.read(cacheProvider);
    final cachedSongs = await cache.getCachedSongs(uid);

    if (cachedSongs.isNotEmpty) {
      debugPrint('📦 CACHE HIT: Loaded ${cachedSongs.length} cached songs for user $uid');
      state = AsyncValue.data(cachedSongs);
    } else {
      debugPrint('📦 CACHE MISS: No cached songs for user $uid, loading...');
      state = const AsyncValue.loading();
    }

    // Step 2: Fetch from network in background
    try {
      final songRepo = ref.read(songRepositoryProvider);
      final songs = await songRepo.watchSongs(uid).first;

      // Step 3: Update cache and notify listeners
      await cache.cacheSongs(uid, songs);
      debugPrint('🌐 ONLINE: Successfully loaded ${songs.length} songs from network for user $uid');
      state = AsyncValue.data(songs);
    } catch (e, st) {
      debugPrint('❌ OFFLINE/ERROR: Failed to load songs from network: $e');
      // If network fails, keep cached data if available
      if (cachedSongs.isNotEmpty) {
        debugPrint('📦 FALLBACK: Using ${cachedSongs.length} cached songs due to network error');
        state = AsyncValue.data(cachedSongs);
      } else {
        debugPrint('⚠️ NO DATA: No cache available, showing error state');
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Watches songs with cache-first strategy and real-time updates.
  void watchSongsWithCache(String uid) {
    // Cancel existing subscription if any
    _subscription?.cancel();

    // Load initial cached data
    loadSongs(uid);

    // Set up real-time listener
    final songRepo = ref.read(songRepositoryProvider);
    final cache = ref.read(cacheProvider);

    _subscription = songRepo
        .watchSongs(uid)
        .listen(
          (songs) async {
            // Update cache on every real-time update
            await cache.cacheSongs(uid, songs);
            debugPrint('🔄 REAL-TIME: Updated ${songs.length} songs from Firestore stream');
            state = AsyncValue.data(songs);
          },
          onError: (error, stackTrace) {
            debugPrint('❌ STREAM ERROR: Real-time song stream error: $error');
            // On error, try to show cached data
            cache.getCachedSongs(uid).then((cachedSongs) {
              if (cachedSongs.isNotEmpty) {
                debugPrint('📦 STREAM FALLBACK: Using ${cachedSongs.length} cached songs');
                state = AsyncValue.data(cachedSongs);
              } else {
                debugPrint('⚠️ STREAM NO CACHE: No cache available for stream error');
                state = AsyncValue.error(error, stackTrace);
              }
            });
          },
        );
  }
}

/// Provider for songs with cache-first strategy.
final cachedSongsProvider =
    NotifierProvider<CachedSongsNotifier, AsyncValue<List<Song>>>(() {
      return CachedSongsNotifier();
    });

/// Stream provider that watches songs for the current user with caching.
///
/// This provider:
/// 1. Immediately returns cached data if available
/// 2. Updates cache from network stream in background
/// 3. Continues to work offline with cached data
final songsProvider = StreamProvider<List<Song>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  
  // Handle loading and error states properly
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      
      final cache = ref.watch(cacheProvider);
      final songRepo = ref.watch(songRepositoryProvider);

      // Return a stream that first emits cached data, then network updates
      return Stream.multi((listener) {
        bool hasEmittedCache = false;

        // Emit cached data immediately
        cache.getCachedSongs(user.uid).then((cachedSongs) {
          if (cachedSongs.isNotEmpty && !listener.isClosed) {
            listener.add(cachedSongs);
            hasEmittedCache = true;
          }
        });

        // Listen to network updates
        final subscription = songRepo
            .watchSongs(user.uid)
            .listen(
              (songs) async {
                // Update cache
                await cache.cacheSongs(user.uid, songs);
                if (!listener.isClosed) {
                  listener.add(songs);
                }
              },
              onError: (error) {
                // On error, emit cached data if not already emitted
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
    },
    loading: () => Stream.value([]),
    error: (error, stack) => Stream.value([]),
  );
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
///
/// IMPORTANT: Properly disposes resources to prevent memory leaks.
class CachedBandsNotifier extends Notifier<AsyncValue<List<Band>>> {
  @override
  AsyncValue<List<Band>> build() {
    return const AsyncValue.loading();
  }

  @override
  void dispose() {
    // No stream subscriptions to cancel in this notifier
  }

  /// Loads bands using cache-first strategy.
  Future<void> loadBands(String uid) async {
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
final bandsProvider = StreamProvider<List<Band>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      
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
    },
    loading: () => Stream.value([]),
    error: (error, stack) => Stream.value([]),
  );
});

/// Notifier that implements cache-first strategy for setlists.
///
/// IMPORTANT: Properly disposes resources to prevent memory leaks.
class CachedSetlistsNotifier extends Notifier<AsyncValue<List<Setlist>>> {
  @override
  AsyncValue<List<Setlist>> build() {
    return const AsyncValue.loading();
  }

  @override
  void dispose() {
    // No stream subscriptions to cancel in this notifier
  }

  /// Loads setlists using cache-first strategy.
  Future<void> loadSetlists(String uid) async {
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
final setlistsProvider = StreamProvider<List<Setlist>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      
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
    },
    loading: () => Stream.value([]),
    error: (error, stack) => Stream.value([]),
  );
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
  return ref.watch(songsProvider).whenOrNull(data: (songs) => songs.length) ??
      0;
});

/// Provider that returns the count of bands.
final bandCountProvider = Provider<int>((ref) {
  return ref.watch(bandsProvider).whenOrNull(data: (bands) => bands.length) ??
      0;
});

/// Provider that returns the count of setlists.
final setlistCountProvider = Provider<int>((ref) {
  return ref
          .watch(setlistsProvider)
          .whenOrNull(data: (setlists) => setlists.length) ??
      0;
});
