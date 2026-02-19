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
  Future<void> saveSong(Song song, String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('songs')
        .doc(song.id)
        .set(song.toJson());
  }

  Future<void> deleteSong(String songId, String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('songs')
        .doc(songId)
        .delete();
  }

  Stream<List<Song>> watchSongs(String uid) {
    return FirebaseFirestore.instance
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
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bands')
        .doc(band.id)
        .set(band.toJson());
  }

  Future<void> deleteBand(String bandId, String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bands')
        .doc(bandId)
        .delete();
  }

  Stream<List<Band>> watchBands(String uid) {
    return FirebaseFirestore.instance
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
