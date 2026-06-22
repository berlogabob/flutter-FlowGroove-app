import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/api_error.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../models/user.dart';
import '../repositories/firestore_song_repository.dart';
import '../repositories/song_repository.dart';

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
  final SongRepository _songRepository = FirestoreSongRepository();

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
    await _songRepository.saveSong(song, uid: uid);
  }

  /// Deletes a song from the user's personal collection.
  Future<void> deleteSong(String songId, {String? uid}) async {
    await _songRepository.deleteSong(songId, uid: uid);
  }

  /// Updates a song in the user's personal collection.
  ///
  /// Uses [update] to merge the new data with existing data,
  /// preserving any fields not included in the song object.
  /// This includes metronome settings: [Song.accentBeats], [Song.regularBeats],
  /// and [Song.beatModes].
  Future<void> updateSong(Song song, {String? uid}) async {
    await _songRepository.updateSong(song, uid: uid);
  }

  /// Watches songs for a user in real-time.
  Stream<List<Song>> watchSongs(String uid) {
    return _songRepository.watchSongs(uid);
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
          .handleError((Object error, StackTrace stackTrace) {
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
                  description: 'Failed to load: $e',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }
            }).toList(),
          )
          .handleError((Object error, StackTrace stackTrace) {
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

  /// Saves a setlist to a band's shared collection.
  Future<void> saveBandSetlist(Setlist setlist, String bandId) async {
    try {
      _requireAuth();
      await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('setlists')
          .doc(setlist.id)
          .set(setlist.copyWith(bandId: bandId).toJson())
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: saveBandSetlist timed out after ${_firestoreTimeout.inSeconds}s for setlist ${setlist.id} in band $bandId',
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
          message: 'You do not have permission to save this band setlist.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Deletes a setlist from a band's shared collection.
  Future<void> deleteBandSetlist(String bandId, String setlistId) async {
    try {
      _requireAuth();
      await _firestore
          .collection('bands')
          .doc(bandId)
          .collection('setlists')
          .doc(setlistId)
          .delete()
          .timeout(_firestoreTimeout);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: deleteBandSetlist timed out after ${_firestoreTimeout.inSeconds}s for setlist $setlistId in band $bandId',
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
          message: 'You do not have permission to delete this band setlist.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Watches setlists for a band in real-time.
  Stream<List<Setlist>> watchBandSetlists(String bandId) {
    try {
      return _firestore
          .collection('bands')
          .doc(bandId)
          .collection('setlists')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                return Setlist.fromJson({...data, 'id': doc.id});
              } catch (e, stackTrace) {
                debugPrint('Failed to parse band setlist ${doc.id}: $e');
                debugPrint('Stack trace: $stackTrace');
                return Setlist(
                  id: doc.id,
                  bandId: bandId,
                  name: 'Error loading setlist',
                  description: 'Failed to load: $e',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }
            }).toList(),
          )
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('Stream error in watchBandSetlists: $error');
            debugPrint('Stack trace: $stackTrace');
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      debugPrint('Error setting up watchBandSetlists: $e');
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
          .get()
          .timeout(_firestoreTimeout);

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id; // Set the document ID
      return Band.fromJson(data);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: getBandByInviteCode timed out after ${_firestoreTimeout.inSeconds}s',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
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
          .get()
          .timeout(_firestoreTimeout);
      return snapshot.docs.isNotEmpty;
    } on TimeoutException catch (e, stackTrace) {
      debugPrint(
        '⏱️ TIMEOUT: isInviteCodeTaken timed out after ${_firestoreTimeout.inSeconds}s',
      );
      throw ApiError.network(
        message:
            'Request timed out. Please check your connection and try again.',
        exception: e,
        stackTrace: stackTrace,
      );
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
    await _songRepository.addSongToBand(
      song: song,
      bandId: bandId,
      contributorId: contributorId,
      contributorName: contributorName,
    );
  }

  /// Add an existing song to a band by song ID.
  ///
  /// This method copies a song from the user's personal library to the band's collection.
  Future<void> addSongToBandById(String songId, String bandId) async {
    await _songRepository.addSongToBandById(songId, bandId);
  }

  /// Saves a song to a band's collection.
  Future<void> saveBandSong(Song song, String bandId) async {
    await _songRepository.saveBandSong(song, bandId);
  }

  /// Watches songs for a specific band.
  Stream<List<Song>> watchBandSongs(String bandId) {
    return _songRepository.watchBandSongs(bandId);
  }

  /// Deletes a song from a band's collection.
  Future<void> deleteBandSong(String bandId, String songId) async {
    await _songRepository.deleteBandSong(bandId, songId);
  }

  /// Updates a song in a band's collection.
  Future<void> updateBandSong(Song song, String bandId) async {
    await _songRepository.updateBandSong(song, bandId);
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
