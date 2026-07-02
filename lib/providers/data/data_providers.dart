import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/band.dart';
import '../../models/canonical_song.dart';
import '../../models/rehearsal.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../repositories/repositories.dart';
import '../../services/band_function_service.dart';
import '../../services/canonical_song_function_service.dart';
import '../../services/firestore_service.dart';
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
  return FirestoreSongRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Provider for the BandRepository.
///
/// Usage:
/// ```dart
/// final bandRepo = ref.read(bandRepositoryProvider);
/// await bandRepo.saveBand(band, uid);
/// ```
final bandRepositoryProvider = Provider<BandRepository>((ref) {
  return FirestoreBandRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Provider for the SetlistRepository.
///
/// Usage:
/// ```dart
/// final setlistRepo = ref.read(setlistRepositoryProvider);
/// await setlistRepo.saveSetlist(setlist, uid);
/// ```
final setlistRepositoryProvider = Provider<SetlistRepository>((ref) {
  return FirestoreSetlistRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Provider for the RehearsalRepository.
final rehearsalRepositoryProvider = Provider<RehearsalRepository>((ref) {
  return FirestoreRehearsalRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Provider for the CanonicalSongRepository.
///
/// Canonical songs are global, read-only catalog records used to deduplicate
/// user and band library entries.
final canonicalSongRepositoryProvider = Provider<CanonicalSongRepository>((
  ref,
) {
  return FirestoreCanonicalSongRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

/// Callable Cloud Function wrapper for creating/finding canonical songs.
final canonicalSongFunctionServiceProvider =
    Provider<CanonicalSongFunctionService>((ref) {
      return CanonicalSongFunctionService();
    });

/// Callable Cloud Function wrapper for band membership (join) operations.
final bandFunctionServiceProvider = Provider<BandFunctionService>((ref) {
  return BandFunctionService();
});

/// Searches the canonical song catalog by title/artist query.
final canonicalSongSearchProvider =
    FutureProvider.family<List<CanonicalSong>, String>((ref, query) async {
      final normalizedQuery = query.trim();
      if (normalizedQuery.length < 2) return const [];

      final repo = ref.watch(canonicalSongRepositoryProvider);
      return repo.search(query: normalizedQuery);
    });

// CacheService is provided once as `cacheServiceProvider` (auth_provider.dart);
// this file reuses it rather than defining a second identical provider.

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

      final cache = ref.watch(cacheServiceProvider);
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
              onError: (Object error) {
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

        listener.onCancel = subscription.cancel;
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

/// Stream provider that watches bands for the current user with caching.
final bandsProvider = StreamProvider<List<Band>>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);

      final cache = ref.watch(cacheServiceProvider);
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
              onError: (Object error) {
                if (!hasEmittedCache && !listener.isClosed) {
                  cache.getCachedBands(user.uid).then((cachedBands) {
                    if (!listener.isClosed) {
                      listener.add(cachedBands);
                    }
                  });
                }
              },
            );

        listener.onCancel = subscription.cancel;
      });
    },
    loading: () => Stream.value([]),
    error: (error, stack) => Stream.value([]),
  );
});

/// Stream provider that watches setlists for the current user.
final setlistsProvider = StreamProvider<List<Setlist>>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      final setlistRepo = ref.watch(setlistRepositoryProvider);
      return setlistRepo.watchSetlists(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (error, stack) => Stream.value([]),
  );
});

// Per-band family providers are autoDispose: their Firestore listeners close
// when no screen is watching them, so visiting N bands does not leave N
// permanent snapshot listeners open for the whole session.

/// Stream provider that watches shared setlists for a band.
final bandSetlistsProvider =
    StreamProvider.autoDispose.family<List<Setlist>, String>((ref, bandId) {
  final setlistRepo = ref.watch(setlistRepositoryProvider);
  return setlistRepo.watchBandSetlists(bandId);
});

/// Stream provider that watches rehearsals for a band.
final bandRehearsalsProvider =
    StreamProvider.autoDispose.family<List<Rehearsal>, String>((ref, bandId) {
  final repo = ref.watch(rehearsalRepositoryProvider);
  return repo.watchRehearsals(bandId);
});

/// Stream provider that watches a single rehearsal ((bandId, rehearsalId)).
final rehearsalProvider =
    StreamProvider.autoDispose.family<Rehearsal?, (String, String)>((ref, key) {
  final repo = ref.watch(rehearsalRepositoryProvider);
  return repo.watchRehearsal(key.$1, key.$2);
});

/// Stream provider that watches votes for a rehearsal ((bandId, rehearsalId)).
final rehearsalVotesProvider = StreamProvider.autoDispose
    .family<Map<String, RehearsalVote>, (String, String)>((ref, key) {
  final repo = ref.watch(rehearsalRepositoryProvider);
  return repo.watchVotes(key.$1, key.$2);
});

/// Stream provider that watches band songs with caching.
final bandSongsProvider =
    StreamProvider.autoDispose.family<List<Song>, String>((ref, bandId) {
  final cache = ref.watch(cacheServiceProvider);
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
          onError: (Object error) {
            if (!hasEmittedCache && !listener.isClosed) {
              cache.getCachedBandSongs(bandId).then((cachedSongs) {
                if (!listener.isClosed) {
                  listener.add(cachedSongs);
                }
              });
            }
          },
        );

    listener.onCancel = subscription.cancel;
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

/// Provider that returns the count of shared setlists for a band.
///
/// autoDispose so it does not pin the autoDispose [bandSetlistsProvider] stream
/// alive after the band screen is gone.
final bandSetlistCountProvider =
    Provider.autoDispose.family<int, String>((ref, bandId) {
  return ref
          .watch(bandSetlistsProvider(bandId))
          .whenOrNull(data: (setlists) => setlists.length) ??
      0;
});
