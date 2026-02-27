import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/song.dart';
import 'song_repository.dart';

/// Timeout duration for Firestore operations (10 seconds).
const _firestoreTimeout = Duration(seconds: 10);

/// Firestore implementation of [SongRepository].
///
/// Handles all song-related data operations with Firestore,
/// including personal songs and band songs.
class FirestoreSongRepository implements SongRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('songs')
          .doc(songId)
          .delete()
          .timeout(_firestoreTimeout);
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
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => Song.fromJson(doc.data())).toList(),
          )
          .handleError((error, stackTrace) {
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

      await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(bandSong.id)
          .set(bandSong.toJson())
          .timeout(const Duration(seconds: 10));
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
        throw ApiError(type: ErrorType.notFound, message: 'Song not found');
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

      await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(bandSong.id)
          .set(bandSong.toJson())
          .timeout(_firestoreTimeout);
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
      return FirebaseFirestore.instance
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => Song.fromJson(doc.data())).toList(),
          )
          .handleError((error, stackTrace) {
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
      await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(songId)
          .delete()
          .timeout(_firestoreTimeout);
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
}
