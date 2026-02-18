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
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});
