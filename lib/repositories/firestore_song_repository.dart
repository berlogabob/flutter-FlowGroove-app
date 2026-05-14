import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/api_error.dart';
import '../models/canonical_song.dart';
import '../models/library_song.dart';
import '../models/song_commit.dart';
import '../models/song_delta.dart';
import '../models/song.dart';
import 'song_repository.dart';

/// Timeout duration for Firestore operations (10 seconds).
const _firestoreTimeout = Duration(seconds: 10);

/// Firestore implementation of [SongRepository].
///
/// Handles all song-related data operations with Firestore,
/// including personal songs and band songs.
class FirestoreSongRepository implements SongRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid = const Uuid();

  FirestoreSongRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Helper method to check if user is authenticated.
  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
  }

  /// Helper method to get current user UID.
  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
    return user.uid;
  }

  @override
  Future<void> saveSong(Song song, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      if (song.canonicalSongId != null && song.canonicalSongId!.isNotEmpty) {
        await _saveLinkedSong(
          song: song,
          docRef: _userSongDoc(userId, song.id),
          ownerType: 'user',
          ownerId: userId,
          authorId: userId,
        );
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('songs')
          .doc(song.id)
          .set(song.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: saveSong timed out after ${_firestoreTimeout.inSeconds}s for song ${song.id}',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to save this song.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deleteSong(String songId, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _deleteSongDocument(
        docRef: _userSongDoc(userId, songId),
        authorId: userId,
      );
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: deleteSong timed out after ${_firestoreTimeout.inSeconds}s for song $songId',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to delete this song.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> updateSong(Song song, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      if (song.canonicalSongId != null && song.canonicalSongId!.isNotEmpty) {
        await _updateLinkedSong(
          song: song,
          docRef: _userSongDoc(userId, song.id),
          ownerType: 'user',
          ownerId: userId,
          authorId: userId,
        );
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('songs')
          .doc(song.id)
          .update(song.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: updateSong timed out after ${_firestoreTimeout.inSeconds}s for song ${song.id}',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to update this song.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      if (e.code == 'not-found') {
        throw ApiError.notFound(
          message: 'This song was not found in your collection.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Stream<List<Song>> watchSongs(String uid) {
    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('songs')
          .snapshots()
          .asyncMap((snapshot) => _songsFromSnapshot(snapshot))
          .handleError((Object error, StackTrace stackTrace) {
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> addSongToBand({
    required Song song,
    required String bandId,
    String? contributorId,
    String? contributorName,
  }) async {
    try {
      _requireAuth();
      final user = _auth.currentUser;
      if (user == null) {
        throw ApiError.auth(
          message: 'Authentication required. Please sign in to continue.',
        );
      }
      final uid = contributorId ?? user.uid;
      final name =
          contributorName ?? user.displayName ?? user.email ?? 'Unknown';

      final bandSong = song.copyWith(
        id: _firestore.collection('bands').doc().id,
        bandId: bandId,
        originalOwnerId: song.originalOwnerId ?? uid,
        originalSongId: song.id, // Track the original song ID for comparison
        contributedBy: name,
        isCopy: true,
        contributedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await saveBandSong(bandSong, bandId);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: addSongToBand timed out after ${_firestoreTimeout.inSeconds}s for band $bandId',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to add songs to this band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> addSongToBandById(String songId, String bandId) async {
    try {
      _requireAuth();
      final user = _auth.currentUser;
      if (user == null) {
        throw ApiError.auth(
          message: 'Authentication required. Please sign in to continue.',
        );
      }

      final songDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('songs')
          .doc(songId)
          .get()
          .timeout(_firestoreTimeout);

      if (!songDoc.exists) {
        throw const ApiError(
          type: ErrorType.notFound,
          message: 'Song not found',
        );
      }

      final songData = songDoc.data()!;
      final song = Song.fromJson(songData);

      final bandSong = song.copyWith(
        id: _firestore.collection('bands').doc().id,
        bandId: bandId,
        originalOwnerId: song.originalOwnerId ?? user.uid,
        contributedBy: user.displayName ?? user.email ?? 'Unknown',
        isCopy: true,
        contributedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await saveBandSong(bandSong, bandId);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: addSongToBandById timed out after ${_firestoreTimeout.inSeconds}s for song $songId to band $bandId',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to add songs to this band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> saveBandSong(Song song, String bandId) async {
    try {
      _requireAuth();
      if (song.canonicalSongId != null && song.canonicalSongId!.isNotEmpty) {
        await _saveLinkedSong(
          song: song,
          docRef: _bandSongDoc(bandId, song.id),
          ownerType: 'band',
          ownerId: bandId,
          authorId: _currentUserId,
        );
        return;
      }

      await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(song.id)
          .set(song.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: saveBandSong timed out after ${_firestoreTimeout.inSeconds}s for song ${song.id} in band $bandId',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to save this song to the band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Stream<List<Song>> watchBandSongs(String bandId) {
    try {
      return _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .snapshots()
          .asyncMap((snapshot) => _songsFromSnapshot(snapshot, bandId: bandId))
          .handleError((Object error, StackTrace stackTrace) {
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deleteBandSong(String bandId, String songId) async {
    try {
      _requireAuth();
      await _deleteSongDocument(
        docRef: _bandSongDoc(bandId, songId),
        authorId: _currentUserId,
      );
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: deleteBandSong timed out after ${_firestoreTimeout.inSeconds}s for song $songId in band $bandId',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message:
              'You do not have permission to delete this song from the band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> updateBandSong(Song song, String bandId) async {
    try {
      _requireAuth();
      if (song.canonicalSongId != null && song.canonicalSongId!.isNotEmpty) {
        await _updateLinkedSong(
          song: song,
          docRef: _bandSongDoc(bandId, song.id),
          ownerType: 'band',
          ownerId: bandId,
          authorId: _currentUserId,
        );
        return;
      }

      await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(song.id)
          .update(song.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: updateBandSong timed out after ${_firestoreTimeout.inSeconds}s for song ${song.id} in band $bandId',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to update this song.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      if (e.code == 'not-found') {
        throw ApiError.notFound(
          message: 'This song was not found in the band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<List<Song>> getSongs(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('songs')
          .get()
          .timeout(_firestoreTimeout);

      return _songsFromSnapshot(snapshot);
    } on TimeoutException {
      throw ApiError.network(message: 'Request timed out. Please try again.');
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  @override
  Future<List<Song>> getBandSongs(String bandId) async {
    try {
      final snapshot = await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .get()
          .timeout(_firestoreTimeout);

      return _songsFromSnapshot(snapshot, bandId: bandId);
    } on TimeoutException {
      throw ApiError.network(message: 'Request timed out. Please try again.');
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  Future<List<Song>> _songsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    String? bandId,
  }) async {
    final entries = <_SongSnapshotEntry>[];
    final canonicalSongIds = <String>{};

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;

        if (_isLinkedSongData(data)) {
          final librarySong = LibrarySong.fromJson(data);
          if (!librarySong.isDeleted) {
            entries.add(_LinkedSongSnapshotEntry(doc.id, librarySong));
            canonicalSongIds.add(librarySong.canonicalSongId);
          }
        } else {
          entries.add(_LegacySongSnapshotEntry(Song.fromJson(data)));
        }
      } catch (e) {
        debugPrint('❌ Failed to parse song ${doc.id}: $e');
      }
    }

    final canonicalsById = await _getCanonicalSongsById(canonicalSongIds);
    final songs = <Song>[];

    for (final entry in entries) {
      try {
        switch (entry) {
          case _LegacySongSnapshotEntry(:final song):
            songs.add(song);
          case _LinkedSongSnapshotEntry(:final docId, :final librarySong):
            songs.add(
              _songFromLibrarySong(
                docId: docId,
                librarySong: librarySong,
                canonical: canonicalsById[librarySong.canonicalSongId],
                bandId: bandId,
              ),
            );
        }
      } catch (e) {
        debugPrint('❌ Failed to merge song snapshot entry: $e');
      }
    }

    return songs;
  }

  bool _isLinkedSongData(Map<String, dynamic> data) {
    return data['schemaVersion'] == LibrarySong.currentSchemaVersion &&
        data['canonicalSongId'] is String &&
        (data['canonicalSongId'] as String).isNotEmpty;
  }

  Song _songFromLibrarySong({
    required String docId,
    required LibrarySong librarySong,
    required CanonicalSong? canonical,
    String? bandId,
  }) {
    if (canonical == null) {
      debugPrint(
        '⚠️ Falling back to materialized song $docId; canonical ${librarySong.canonicalSongId} unavailable',
      );
      return librarySong.materialized.copyWith(
        libraryBaseRevision: librarySong.baseRevision,
        latestCommitId: librarySong.latestCommitId,
      );
    }

    final materialized = librarySong.materialized;
    return librarySong.delta
        .applyTo(
          canonical: canonical,
          librarySongId: librarySong.id.isNotEmpty ? librarySong.id : docId,
          bandId: materialized.bandId ?? bandId,
          createdAt: librarySong.createdAt,
          updatedAt: librarySong.updatedAt,
          originalOwnerId: materialized.originalOwnerId,
          originalSongId: materialized.originalSongId,
          contributedBy: materialized.contributedBy,
          isCopy: materialized.isCopy,
          contributedAt: materialized.contributedAt,
        )
        .copyWith(
          libraryBaseRevision: librarySong.baseRevision,
          latestCommitId: librarySong.latestCommitId,
        );
  }

  Future<Map<String, CanonicalSong>> _getCanonicalSongsById(
    Set<String> canonicalSongIds,
  ) async {
    final result = <String, CanonicalSong>{};
    final ids = canonicalSongIds.where((id) => id.isNotEmpty).toList();

    for (var start = 0; start < ids.length; start += 10) {
      final end = start + 10 > ids.length ? ids.length : start + 10;
      final chunk = ids.sublist(start, end);

      try {
        final snapshot = await _firestore
            .collection('canonical_songs')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
            .timeout(_firestoreTimeout);

        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] ??= doc.id;
          result[doc.id] = CanonicalSong.fromJson(data);
        }
      } catch (e) {
        debugPrint(
          '⚠️ Failed to batch fetch canonical songs ${chunk.join(', ')}: $e',
        );
      }
    }

    return result;
  }

  Future<CanonicalSong?> _getCanonicalSong(String canonicalSongId) async {
    final doc = await _firestore
        .collection('canonical_songs')
        .doc(canonicalSongId)
        .get()
        .timeout(_firestoreTimeout);

    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    data['id'] ??= doc.id;
    return CanonicalSong.fromJson(data);
  }

  DocumentReference<Map<String, dynamic>> _userSongDoc(
    String userId,
    String songId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('songs')
        .doc(songId);
  }

  DocumentReference<Map<String, dynamic>> _bandSongDoc(
    String bandId,
    String songId,
  ) {
    return _firestore
        .collection('bands')
        .doc(bandId)
        .collection('songs')
        .doc(songId);
  }

  Future<void> _saveLinkedSong({
    required Song song,
    required DocumentReference<Map<String, dynamic>> docRef,
    required String ownerType,
    required String ownerId,
    required String authorId,
  }) async {
    final canonical = await _getCanonicalSong(song.canonicalSongId!);
    if (canonical == null) {
      throw ApiError.notFound(
        message: 'Canonical song ${song.canonicalSongId} was not found.',
      );
    }

    final delta = SongDelta.compute(canonical: canonical, song: song);
    final commitId = docRef.collection('commits').doc().id;
    final now = DateTime.now();
    final materialized = song.copyWith(updatedAt: now);
    final librarySong = LibrarySong(
      id: song.id,
      canonicalSongId: canonical.id,
      ownerType: ownerType,
      ownerId: ownerId,
      baseRevision: canonical.canonicalRevision,
      delta: delta,
      materialized: materialized,
      latestCommitId: commitId,
      createdAt: song.createdAt,
      updatedAt: now,
    );
    final commit = SongCommit(
      id: commitId,
      canonicalSongId: canonical.id,
      baseRevision: canonical.canonicalRevision,
      delta: delta,
      operation: 'create',
      authorId: authorId,
      message: 'Create linked song',
      clientMutationId: _uuid.v4(),
      createdAt: now,
    );

    final batch = _firestore.batch();
    batch.set(docRef, librarySong.toJson());
    batch.set(docRef.collection('commits').doc(commitId), commit.toJson());
    await batch.commit().timeout(_firestoreTimeout);
  }

  Future<void> _updateLinkedSong({
    required Song song,
    required DocumentReference<Map<String, dynamic>> docRef,
    required String ownerType,
    required String ownerId,
    required String authorId,
  }) async {
    final canonical = await _getCanonicalSong(song.canonicalSongId!);
    if (canonical == null) {
      throw ApiError.notFound(
        message: 'Canonical song ${song.canonicalSongId} was not found.',
      );
    }

    await _firestore
        .runTransaction((transaction) async {
          final existingDoc = await transaction.get(docRef);
          LibrarySong? existing;
          if (existingDoc.exists) {
            final data = existingDoc.data();
            if (data != null &&
                data['schemaVersion'] == LibrarySong.currentSchemaVersion) {
              data['id'] ??= existingDoc.id;
              existing = LibrarySong.fromJson(data);
            }
          }

          if (existing != null) {
            if (song.latestCommitId != null &&
                existing.latestCommitId != song.latestCommitId) {
              throw ApiError.validation(
                message:
                    'This song changed in another session. Reload it before saving again.',
              );
            }
            if (song.libraryBaseRevision != null &&
                existing.baseRevision != song.libraryBaseRevision) {
              throw ApiError.validation(
                message:
                    'This song is based on a different canonical revision. Reload it before saving again.',
              );
            }
          }

          final delta = SongDelta.compute(canonical: canonical, song: song);
          final commitId = docRef.collection('commits').doc().id;
          final now = DateTime.now();
          final materialized = song.copyWith(updatedAt: now);
          final librarySong = LibrarySong(
            id: song.id,
            canonicalSongId: canonical.id,
            ownerType: ownerType,
            ownerId: ownerId,
            baseRevision: canonical.canonicalRevision,
            delta: delta,
            materialized: materialized,
            latestCommitId: commitId,
            createdAt: existing?.createdAt ?? song.createdAt,
            updatedAt: now,
          );
          final commit = SongCommit(
            id: commitId,
            parentCommitId: existing?.latestCommitId,
            canonicalSongId: canonical.id,
            baseRevision: canonical.canonicalRevision,
            delta: delta,
            operation: existing == null ? 'create' : 'update',
            authorId: authorId,
            message: existing == null
                ? 'Create linked song'
                : 'Update linked song',
            clientMutationId: _uuid.v4(),
            createdAt: now,
          );

          transaction.set(docRef, librarySong.toJson());
          transaction.set(
            docRef.collection('commits').doc(commitId),
            commit.toJson(),
          );
        })
        .timeout(_firestoreTimeout);
  }

  Future<void> _deleteSongDocument({
    required DocumentReference<Map<String, dynamic>> docRef,
    required String authorId,
  }) async {
    await _firestore
        .runTransaction((transaction) async {
          final existingDoc = await transaction.get(docRef);
          if (!existingDoc.exists) {
            throw ApiError.notFound(message: 'This song was not found.');
          }

          final data = existingDoc.data();
          if (data == null || !_isLinkedSongData(data)) {
            transaction.delete(docRef);
            return;
          }

          data['id'] ??= existingDoc.id;
          final existing = LibrarySong.fromJson(data);
          final now = DateTime.now();
          final commitId = docRef.collection('commits').doc().id;
          final deletedLibrarySong = LibrarySong(
            id: existing.id,
            schemaVersion: existing.schemaVersion,
            canonicalSongId: existing.canonicalSongId,
            ownerType: existing.ownerType,
            ownerId: existing.ownerId,
            baseRevision: existing.baseRevision,
            delta: existing.delta,
            materialized: existing.materialized.copyWith(updatedAt: now),
            latestCommitId: commitId,
            createdAt: existing.createdAt,
            updatedAt: now,
            deletedAt: now,
          );
          final commit = SongCommit(
            id: commitId,
            parentCommitId: existing.latestCommitId,
            canonicalSongId: existing.canonicalSongId,
            baseRevision: existing.baseRevision,
            delta: existing.delta,
            operation: 'delete',
            authorId: authorId,
            message: 'Delete linked song',
            clientMutationId: _uuid.v4(),
            createdAt: now,
          );

          transaction.set(docRef, deletedLibrarySong.toJson());
          transaction.set(
            docRef.collection('commits').doc(commitId),
            commit.toJson(),
          );
        })
        .timeout(_firestoreTimeout);
  }
}

sealed class _SongSnapshotEntry {
  const _SongSnapshotEntry();
}

class _LegacySongSnapshotEntry extends _SongSnapshotEntry {
  const _LegacySongSnapshotEntry(this.song);

  final Song song;
}

class _LinkedSongSnapshotEntry extends _SongSnapshotEntry {
  const _LinkedSongSnapshotEntry(this.docId, this.librarySong);

  final String docId;
  final LibrarySong librarySong;
}
