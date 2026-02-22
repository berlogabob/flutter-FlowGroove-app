import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/api_error.dart';
import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';

/// Firestore service for handling all database operations.
///
/// Provides CRUD operations for songs, bands, and setlists,
/// as well as band sharing and song sharing functionality.
///
/// All methods throw [ApiError] exceptions for proper error handling.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // Song Operations (Personal)
  // ============================================================

  /// Saves a song to the user's personal collection.
  Future<void> saveSong(Song song, String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('songs')
          .doc(song.id)
          .set(song.toJson());
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
  Future<void> deleteSong(String songId, String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('songs')
          .doc(songId)
          .delete();
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
  Future<void> saveBand(Band band, String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .doc(band.id)
          .set(band.toJson());
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
  Future<void> deleteBand(String bandId, String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bands')
          .doc(bandId)
          .delete();
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
  Future<void> saveSetlist(Setlist setlist, String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('setlists')
          .doc(setlist.id)
          .set(setlist.toJson());
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
  Future<void> deleteSetlist(String setlistId, String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('setlists')
          .doc(setlistId)
          .delete();
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
            (snapshot) => snapshot.docs
                .map((doc) => Setlist.fromJson(doc.data()))
                .toList(),
          )
          .handleError((error, stackTrace) {
            throw ApiError.fromException(error, stackTrace: stackTrace);
          });
    } catch (e, stackTrace) {
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  // ============================================================
  // Global Bands Collection Methods (for cross-user sharing)
  // ============================================================

  /// Saves a band to the global 'bands' collection.
  Future<void> saveBandToGlobal(Band band) async {
    try {
      await FirebaseFirestore.instance
          .collection('bands')
          .doc(band.id)
          .set(band.toJson());
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
      final snapshot = await FirebaseFirestore.instance
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
      final snapshot = await FirebaseFirestore.instance
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
  Future<void> addUserToBand(String bandId, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('bands')
          .doc(bandId)
          .set({'bandId': bandId, 'joinedAt': FieldValue.serverTimestamp()});
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
  Future<void> removeUserFromBand(String bandId, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('bands')
          .doc(bandId)
          .delete();
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
    required String contributorId,
    required String contributorName,
  }) async {
    try {
      final bandSong = song.copyWith(
        id: FirebaseFirestore.instance.collection('bands').doc().id,
        bandId: bandId,
        originalOwnerId: song.originalOwnerId ?? contributorId,
        contributedBy: contributorName,
        isCopy: true,
        contributedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(bandSong.id)
          .set(bandSong.toJson());
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
      await FirebaseFirestore.instance
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(songId)
          .delete();
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
      await FirebaseFirestore.instance
          .collection('bands')
          .doc(bandId)
          .collection('songs')
          .doc(song.id)
          .update(song.toJson());
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
