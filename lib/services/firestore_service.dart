import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import '../models/user.dart';

/// Timeout duration for Firestore operations (10 seconds).
const _firestoreTimeout = Duration(seconds: 10);

/// Firestore service for handling all database operations.
///
/// Provides CRUD operations for songs, bands, and setlists,
/// as well as band sharing and song sharing functionality.
///
/// All methods throw [ApiError] exceptions for proper error handling.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Helper method to check if user is authenticated.
  /// Throws [ApiError] if not authenticated.
  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
  }

  /// Helper method to get current user UID.
  /// Throws [ApiError] if not authenticated.
  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw ApiError.auth(
        message: 'Authentication required. Please sign in to continue.',
      );
    }
    return user.uid;
  }

  // ============================================================
  // Song Operations (Personal)
  // ============================================================

  /// Saves a song to the user's personal collection.
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

  /// Deletes a song from the user's personal collection.
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

  /// Updates a song in the user's personal collection.
  ///
  /// Uses [update] to merge the new data with existing data,
  /// preserving any fields not included in the song object.
  /// This includes metronome settings: [Song.accentBeats], [Song.regularBeats],
  /// and [Song.beatModes].
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

  /// Watches songs for a user in real-time.
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

  // ============================================================
  // Band Operations (Personal References)
  // ============================================================

  /// Saves a band reference to the user's collection.
  Future<void> saveBand(Band band, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bands')
          .doc(band.id)
          .set(band.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: saveBand timed out after ${_firestoreTimeout.inSeconds}s for band ${band.id}',
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
          message: 'You do not have permission to save this band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Deletes a band reference from the user's collection.
  Future<void> deleteBand(String bandId, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bands')
          .doc(bandId)
          .delete()
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: deleteBand timed out after ${_firestoreTimeout.inSeconds}s for band $bandId',
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
          message: 'You do not have permission to delete this band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Watches bands for a user by fetching from the global collection.
  ///
  /// First gets the user's band IDs from their collection,
  /// then fetches full band data from the global 'bands' collection.
  Stream<List<Band>> watchBands(String uid) {
    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .snapshots()
          .asyncMap((snapshot) async {
            final bandIds = snapshot.docs.map((doc) => doc.id).toList();

            if (bandIds.isEmpty) return <Band>[];

            // Fetch full band data from global collection
            final bands = <Band>[];
            for (final bandId in bandIds) {
              try {
                final bandDoc = await _firestore
                    .collection('bands')
                    .doc(bandId)
                    .get();
                if (bandDoc.exists) {
                  final data = bandDoc.data()!;
                  data['id'] = bandDoc.id; // Set the document ID
                  bands.add(Band.fromJson(data));
                }
              } on FirebaseException catch (e) {
                if (e.code == 'not-found') {
                  // Band was deleted, skip it
                  continue;
                }
                rethrow;
              }
            }
            return bands;
          })
          .handleError((error, stackTrace) {
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  // ============================================================
  // Setlist Operations
  // ============================================================

  /// Saves a setlist to the user's collection.
  Future<void> saveSetlist(Setlist setlist, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('setlists')
          .doc(setlist.id)
          .set(setlist.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: saveSetlist timed out after ${_firestoreTimeout.inSeconds}s for setlist ${setlist.id}',
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
          message: 'You do not have permission to save this setlist.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Deletes a setlist from the user's collection.
  Future<void> deleteSetlist(String setlistId, {String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('setlists')
          .doc(setlistId)
          .delete()
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: deleteSetlist timed out after ${_firestoreTimeout.inSeconds}s for setlist $setlistId',
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
          message: 'You do not have permission to delete this setlist.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Watches setlists for a user in real-time.
  Stream<List<Setlist>> watchSetlists(String uid) {
    try {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('setlists')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              try {
                return Setlist.fromJson(doc.data());
              } catch (e, stackTrace) {
                debugPrint('Failed to parse setlist ${doc.id}: $e');
                debugPrint('Stack trace: $stackTrace');
                // Return a default setlist with error info
                return Setlist(
                  id: doc.id,
                  bandId: '',
                  name: 'Error loading setlist',
                  description: 'Failed to load: ${e.toString()}',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }
            }).toList(),
          )
          .handleError((error, stackTrace) {
            debugPrint('Stream error in watchSetlists: $error');
            debugPrint('Stack trace: $stackTrace');
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      debugPrint('Error setting up watchSetlists: $e');
      debugPrint('Stack trace: $stackTrace');
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  // ============================================================
  // Global Bands Collection Methods (for cross-user sharing)
  // ============================================================

  /// Saves a band to the global 'bands' collection.
  Future<void> saveBandToGlobal(Band band) async {
    try {
      _requireAuth();
      await _firestore
          .collection('bands')
          .doc(band.id)
          .set(band.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: saveBandToGlobal timed out after ${_firestoreTimeout.inSeconds}s for band ${band.id}',
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
          message: 'You do not have permission to modify this band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Gets a band by invite code from global collection.
  Future<Band?> getBandByInviteCode(String code) async {
    try {
      _requireAuth();
      final snapshot = await _firestore
          .collection('bands')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id; // Set the document ID
      return Band.fromJson(data);
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'not-found') {
        return null;
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Checks if invite code is already taken.
  Future<bool> isInviteCodeTaken(String code) async {
    try {
      _requireAuth();
      final snapshot = await _firestore
          .collection('bands')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Adds user reference to a band (for joining).
  Future<void> addUserToBand(String bandId, {String? userId}) async {
    try {
      final uid = userId ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .doc(bandId)
          .set({'bandId': bandId, 'joinedAt': FieldValue.serverTimestamp()})
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: addUserToBand timed out after ${_firestoreTimeout.inSeconds}s for band $bandId',
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
          message: 'You do not have permission to join this band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Removes user reference from a band (for leaving).
  Future<void> removeUserFromBand(String bandId, {String? userId}) async {
    try {
      final uid = userId ?? _currentUserId;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .doc(bandId)
          .delete()
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: removeUserFromBand timed out after ${_firestoreTimeout.inSeconds}s for band $bandId',
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
          message: 'You do not have permission to leave this band.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  // ============================================================
  // Band Songs Methods (for sharing songs between personal and band banks)
  // ============================================================

  /// Adds a song to a band's song collection.
  ///
  /// Creates a copy of the personal song with sharing metadata.
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

  /// Add an existing song to a band by song ID.
  ///
  /// This method copies a song from the user's personal library to the band's collection.
  Future<void> addSongToBandById(String songId, String bandId) async {
    try {
      _requireAuth();
      final user = _auth.currentUser;
      if (user == null) {
        throw ApiError.auth(
          message: 'Authentication required. Please sign in to continue.',
        );
      }

      // Get the song from user's personal library
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

      // Create a copy for the band
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

  /// Saves a song to a band's collection.
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

  /// Watches songs for a specific band.
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

  /// Deletes a song from a band's collection.
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

  /// Updates a song in a band's collection.
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

  // ============================================================
  // User Operations
  // ============================================================

  /// Saves user profile data to Firestore.
  Future<void> saveUser(AppUser user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(user.toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ TIMEOUT: saveUser timed out for user ${user.uid}');
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to save your profile.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Loads user profile from Firestore.
  Future<AppUser?> loadUser(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(_firestoreTimeout);

      if (!doc.exists) return null;
      return AppUser.fromJson(doc.data()!);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ TIMEOUT: loadUser timed out for user $uid');
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Updates user profile fields in Firestore.
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoURL != null) updates['photoURL'] = photoURL;

      if (updates.isEmpty) return;

      await _firestore
          .collection('users')
          .doc(uid)
          .update(updates)
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ TIMEOUT: updateUserProfile timed out for user $uid');
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        throw ApiError.permission(
          message: 'You do not have permission to update your profile.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Gets all tags used by the user with their counts (tag cloud).
  ///
  /// Returns a map of tag to count, sorted by count descending.
  Future<Map<String, int>> getTagCloud({String? uid}) async {
    try {
      final userId = uid ?? _currentUserId;
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('songs')
          .get()
          .timeout(_firestoreTimeout);

      final tagCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tags = data['tags'] as List<dynamic>?;
        if (tags != null) {
          for (final tag in tags) {
            final tagStr = (tag as String).toLowerCase();
            tagCounts[tagStr] = (tagCounts[tagStr] ?? 0) + 1;
          }
        }
      }

      // Sort by count descending
      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Map.fromEntries(sortedTags);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ TIMEOUT: getTagCloud timed out for user $uid');
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
