import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../models/band.dart';
import '../../models/canonical_song.dart';
import '../../models/rehearsal.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../models/song_lab.dart';
import '../../repositories/repositories.dart';
import '../../services/band_function_service.dart';
import '../../services/canonical_song_function_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pending_storage_deletes.dart';
import '../../services/rehearsal_function_service.dart';
import '../../services/storage_service.dart';
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

/// Provider for StorageService — a seam so screens that upload can be tested
/// without Firebase.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Queue of audio objects awaiting deletion once their undo window closes.
final pendingStorageDeletesProvider = Provider<PendingStorageDeletes>((ref) {
  return PendingStorageDeletes(storage: ref.watch(storageServiceProvider));
});

/// Fetches the bytes behind a Firebase Storage download URL.
///
/// Plain `http` rather than `Reference.getData()`: on web the SDK is literally
/// `getDownloadURL()` + `http.readBytes` (so there's no CORS advantage), its
/// 10MB default silently returns null for a typical take, and the tokenised URL
/// sidesteps the uid-locked read rule on `lab_audio/user/{uid}/…` that would
/// deny a band member.
final audioBytesFetcherProvider = Provider<Future<Uint8List> Function(String)>((
  ref,
) {
  return (url) => http.readBytes(Uri.parse(url));
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

/// Song Lab (#66): repository + per-song streams. Family key: (songId, bandId
/// — null for personal songs).
final labRepositoryProvider = Provider<FirestoreLabRepository>((ref) {
  return FirestoreLabRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final labEntriesProvider = StreamProvider.autoDispose
    .family<List<SongLabEntry>, (String, String?)>((ref, key) {
      final (songId, bandId) = key;
      return ref
          .watch(labRepositoryProvider)
          .watchEntries(songId, bandId: bandId);
    });

final labTasksProvider = StreamProvider.autoDispose
    .family<List<SongTask>, (String, String?)>((ref, key) {
      final (songId, bandId) = key;
      return ref.watch(labRepositoryProvider).watchTasks(songId, bandId: bandId);
    });

/// One-shot open-task count for a song — the rehearsal "what to prepare"
/// line (#68). Key: (songId, bandId).
final openTaskCountProvider = FutureProvider.autoDispose
    .family<int, (String, String?)>((ref, key) {
      final (songId, bandId) = key;
      return ref
          .watch(labRepositoryProvider)
          .openTaskCount(songId, bandId: bandId);
    });

final labVersionsProvider = StreamProvider.autoDispose
    .family<List<SongVersion>, (String, String?)>((ref, key) {
      final (songId, bandId) = key;
      return ref
          .watch(labRepositoryProvider)
          .watchVersions(songId, bandId: bandId);
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

/// Callable Cloud Function wrapper for rehearsal-plan actions (e.g. remind
/// non-voters).
final rehearsalFunctionServiceProvider = Provider<RehearsalFunctionService>((
  ref,
) {
  return RehearsalFunctionService();
});

/// Searches the canonical song catalog by title/artist query.
final canonicalSongSearchProvider =
    FutureProvider.family<List<CanonicalSong>, String>((ref, query) async {
      final normalizedQuery = query.trim();
      if (normalizedQuery.length < 2) return const [];

      final repo = ref.watch(canonicalSongRepositoryProvider);
      return repo.search(query: normalizedQuery);
    });

// Offline support comes from Firestore's built-in persistence (enabled in
// main.dart), so these providers expose the raw real-time streams. The old
// Hive cache-first wrappers raced the live stream and could re-emit stale
// data after fresh data (#91 phantom items).

/// Stream provider that watches songs for the current user.
final songsProvider = StreamProvider<List<Song>>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      final songRepo = ref.watch(songRepositoryProvider);
      return songRepo.watchSongs(user.uid);
    },
    loading: () => Stream.value([]),
    error: (error, stack) => Stream.value([]),
  );
});

/// Stream provider that watches bands for the current user.
final bandsProvider = StreamProvider<List<Band>>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      final bandRepo = ref.watch(bandRepositoryProvider);
      return bandRepo.watchBands(user.uid);
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
    // Stream.value, not Stream.empty: an empty stream never emits, leaving the
    // provider in loading forever (Setlists screen hang) — matches songs/bands.
    loading: () => Stream.value([]),
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

/// Stream provider that watches band songs.
final bandSongsProvider =
    StreamProvider.autoDispose.family<List<Song>, String>((ref, bandId) {
  final songRepo = ref.watch(songRepositoryProvider);
  return songRepo.watchBandSongs(bandId);
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
