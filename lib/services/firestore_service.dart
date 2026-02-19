import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import '../providers/auth_provider.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final songsCollectionProvider = Provider<CollectionReference>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('Not authenticated');
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .collection('songs');
});

final bandsCollectionProvider = Provider<CollectionReference>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('Not authenticated');
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .collection('bands');
});

final setlistsCollectionProvider = Provider<CollectionReference>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('Not authenticated');
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .collection('setlists');
});

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);

  Future<void> saveSong(Song song, String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('songs')
        .doc(song.id)
        .set(song.toJson());
  }

  Future<void> deleteSong(String songId, String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('songs')
        .doc(songId)
        .delete();
  }

  Stream<List<Song>> watchSongs(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('songs')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Song.fromJson(doc.data())).toList(),
        );
  }

  Future<void> saveBand(Band band, String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('bands')
        .doc(band.id)
        .set(band.toJson());
  }

  Future<void> deleteBand(String bandId, String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('bands')
        .doc(bandId)
        .delete();
  }

  Stream<List<Band>> watchBands(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('bands')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Band.fromJson(doc.data())).toList(),
        );
  }

  Future<void> saveSetlist(Setlist setlist, String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('setlists')
        .doc(setlist.id)
        .set(setlist.toJson());
  }

  Future<void> deleteSetlist(String setlistId, String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('setlists')
        .doc(setlistId)
        .delete();
  }

  Stream<List<Setlist>> watchSetlists(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('setlists')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Setlist.fromJson(doc.data())).toList(),
        );
  }

  // ============================================================
  // Global Bands Collection Methods
  // ============================================================
  // These methods enable band sharing across users by storing
  // bands in a global collection instead of user-specific collections.

  /// Saves a band to the global 'bands' collection.
  /// 
  /// This makes the band accessible to all users via invite code.
  Future<void> saveBandToGlobal(Band band) async {
    await _firestore
        .collection('bands')  // Global collection
        .doc(band.id)
        .set(band.toJson());
  }

  /// Retrieves a band by its invite code from the global collection.
  /// 
  /// Returns null if no band with the given code exists.
  Future<Band?> getBandByInviteCode(String code) async {
    final snapshot = await _firestore
        .collection('bands')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    return Band.fromJson(snapshot.docs.first.data() as Map<String, dynamic>);
  }

  /// Checks if an invite code is already taken by another band.
  /// 
  /// Returns true if a band with the given code exists, false otherwise.
  Future<bool> isInviteCodeTaken(String code) async {
    final snapshot = await _firestore
        .collection('bands')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Adds a user reference to their bands collection for a specific band.
  /// 
  /// This creates a link in the user's collection pointing to the global band.
  /// The bandId is used as the document ID for easy lookup.
  Future<void> addUserToBand(String bandId, String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('bands')
        .doc(bandId)
        .set({'bandId': bandId, 'joinedAt': FieldValue.serverTimestamp()});
  }

  /// Removes a user reference from their bands collection.
  /// 
  /// This removes the link but does not delete the global band document.
  Future<void> removeUserFromBand(String bandId, String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('bands')
        .doc(bandId)
        .delete();
  }

  /// Gets all band IDs that a user is a member of from their user collection.
  /// 
  /// Returns a list of band IDs (not full band data).
  Future<List<String>> getUserBandIds(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('bands')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Gets a band by its ID from the global collection.
  /// 
  /// Returns null if the band doesn't exist.
  Future<Band?> getBandById(String bandId) async {
    final doc = await _firestore.collection('bands').doc(bandId).get();
    if (!doc.exists) return null;
    return Band.fromJson(doc.data() as Map<String, dynamic>);
  }
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});
