import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song.dart';
import '../models/band.dart';
import '../models/setlist.dart';
import 'auth_provider.dart';

final firestoreProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Watches bands for a user by fetching from the global collection.
  ///
  /// First gets the user's band IDs from their collection,
  /// then fetches full band data from the global 'bands' collection.
  Stream<List<Band>> watchBands(String uid) {
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
            final bandDoc = await _firestore.collection('bands').doc(bandId).get();
            if (bandDoc.exists) {
              final data = bandDoc.data()!;
              data['id'] = bandDoc.id; // Set the document ID
              bands.add(Band.fromJson(data));
            }
          }
          return bands;
        });
  }

  Future<void> saveSetlist(Setlist setlist, String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('setlists')
        .doc(setlist.id)
        .set(setlist.toJson());
  }

  Future<void> deleteSetlist(String setlistId, String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('setlists')
        .doc(setlistId)
        .delete();
  }

  Stream<List<Setlist>> watchSetlists(String uid) {
    return FirebaseFirestore.instance
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
  // Global Bands Collection Methods (for cross-user sharing)
  // ============================================================

  /// Saves a band to the global 'bands' collection.
  Future<void> saveBandToGlobal(Band band) async {
    await FirebaseFirestore.instance
        .collection('bands')
        .doc(band.id)
        .set(band.toJson());
  }

  /// Gets a band by invite code from global collection.
  Future<Band?> getBandByInviteCode(String code) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bands')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data()!;
    data['id'] = doc.id; // Set the document ID
    return Band.fromJson(data);
  }

  /// Checks if invite code is already taken.
  Future<bool> isInviteCodeTaken(String code) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bands')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Adds user reference to a band (for joining).
  Future<void> addUserToBand(String bandId, String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bands')
        .doc(bandId)
        .set({
          'bandId': bandId,
          'joinedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Removes user reference from a band (for leaving).
  Future<void> removeUserFromBand(String bandId, String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bands')
        .doc(bandId)
        .delete();
  }
}

final songsProvider = StreamProvider<List<Song>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreProvider).watchSongs(user.uid);
});

final bandsProvider = StreamProvider<List<Band>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreProvider).watchBands(user.uid);
});

final setlistsProvider = StreamProvider<List<Setlist>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreProvider).watchSetlists(user.uid);
});

class SelectedBandNotifier extends Notifier<Band?> {
  @override
  Band? build() => null;

  void select(Band? band) {
    state = band;
  }
}

final selectedBandProvider = NotifierProvider<SelectedBandNotifier, Band?>(() {
  return SelectedBandNotifier();
});

final songCountProvider = Provider<int>((ref) {
  return ref.watch(songsProvider).whenOrNull(data: (songs) => songs.length) ??
      0;
});

final bandCountProvider = Provider<int>((ref) {
  return ref.watch(bandsProvider).whenOrNull(data: (bands) => bands.length) ??
      0;
});

final setlistCountProvider = Provider<int>((ref) {
  return ref
          .watch(setlistsProvider)
          .whenOrNull(data: (setlists) => setlists.length) ??
      0;
});
