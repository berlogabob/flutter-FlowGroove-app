import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/api_error.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../models/user.dart';
import '../repositories/band_repository.dart';
import '../repositories/firestore_band_repository.dart';
import '../repositories/firestore_setlist_repository.dart';
import '../repositories/firestore_song_repository.dart';
import '../repositories/setlist_repository.dart';
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
  final SetlistRepository _setlistRepository = FirestoreSetlistRepository();
  final BandRepository _bandRepository = FirestoreBandRepository();

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
    await _bandRepository.saveBand(band, uid: uid);
  }

  // ============================================================
  // Setlist Operations
  // ============================================================

  /// Saves a setlist to the user's collection.
  ///
  /// Scope is derived from the data, never trusted from the caller: the
  /// repository routes a setlist carrying a bandId to the band collection.
  Future<void> saveSetlist(Setlist setlist, {String? uid}) async {
    await _setlistRepository.saveSetlist(setlist, uid: uid);
  }

  /// Deletes a setlist from the user's collection.
  Future<void> deleteSetlist(String setlistId, {String? uid}) async {
    await _setlistRepository.deleteSetlist(setlistId, uid: uid);
  }

  /// Saves a setlist to a band's shared collection.
  Future<void> saveBandSetlist(Setlist setlist, String bandId) async {
    await _setlistRepository.saveBandSetlist(setlist, bandId);
  }

  /// Writes ONE area of the event kit (`stage` / `rider` / `people`) using a
  /// dotted field path, leaving every other field of the setlist untouched.
  ///
  /// This is the only supported way to save event-kit changes — see
  /// [SetlistRepository.updateEventKitArea] for why.
  Future<void> updateEventKitArea({
    required String setlistId,
    required String area,
    required Object? value,
    String? bandId,
    String? uid,
  }) async {
    await _setlistRepository.updateEventKitArea(
      setlistId: setlistId,
      area: area,
      value: value,
      bandId: bandId,
      uid: uid,
    );
  }

  /// Deletes a setlist from a band's shared collection.
  Future<void> deleteBandSetlist(String bandId, String setlistId) async {
    await _setlistRepository.deleteBandSetlist(bandId, setlistId);
  }

  // ============================================================
  // Global Bands Collection Methods (for cross-user sharing)
  // ============================================================

  /// Saves a band to the global 'bands' collection.
  Future<void> saveBandToGlobal(Band band) async {
    await _bandRepository.saveBandToGlobal(band);
  }

  /// Writes a band to BOTH the global `bands/{id}` collection and the user's
  /// `users/{uid}/bands/{id}` reference in a single atomic batch (one round
  /// trip) instead of two sequential `set` calls — used on band create/edit.
  Future<void> saveBandBatch(Band band, {String? uid}) async {
    await _bandRepository.saveBandBatch(band, uid: uid);
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
