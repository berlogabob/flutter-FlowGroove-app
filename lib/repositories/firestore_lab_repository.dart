import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/song_lab.dart';

/// Firestore access for Song Lab subcollections (#66) under a song doc:
/// `labEntries`, `tasks`, `versions` — for personal songs
/// (`users/{uid}/songs/{songId}`) and band songs
/// (`bands/{bandId}/songs/{songId}`), selected by [bandId].
///
/// ponytail: single concrete class, no interface — one implementation exists.
class FirestoreLabRepository {
  FirestoreLabRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _songDoc(
    String songId, {
    String? bandId,
  }) => bandId != null
      ? _firestore.collection('bands').doc(bandId).collection('songs').doc(songId)
      : _firestore.collection('users').doc(_uid).collection('songs').doc(songId);

  // ---- Entries ----

  Stream<List<SongLabEntry>> watchEntries(String songId, {String? bandId}) =>
      _songDoc(songId, bandId: bandId)
          .collection('labEntries')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs.map((d) => SongLabEntry.fromJson(d.data())).toList(),
          );

  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) =>
      _songDoc(entry.songId, bandId: bandId)
          .collection('labEntries')
          .doc(entry.id)
          .set(entry.toJson());

  Future<void> deleteEntry(
    String songId,
    String entryId, {
    String? bandId,
  }) => _songDoc(songId, bandId: bandId)
      .collection('labEntries')
      .doc(entryId)
      .delete();

  // ---- Tasks ----

  Stream<List<SongTask>> watchTasks(String songId, {String? bandId}) =>
      _songDoc(songId, bandId: bandId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => SongTask.fromJson(d.data())).toList());

  Future<void> saveTask(SongTask task, {String? bandId}) =>
      _songDoc(task.songId, bandId: bandId)
          .collection('tasks')
          .doc(task.id)
          .set(task.toJson());

  Future<void> deleteTask(String songId, String taskId, {String? bandId}) =>
      _songDoc(songId, bandId: bandId).collection('tasks').doc(taskId).delete();

  /// Open tasks for one song, one-shot (the Practice screen homework list,
  /// #68/#133).
  Future<List<SongTask>> listOpenTasks(String songId, {String? bandId}) async {
    final snap = await _songDoc(songId, bandId: bandId)
        .collection('tasks')
        .where('status', whereIn: ['todo', 'doing', 'blocked'])
        .get();
    return snap.docs.map((d) => SongTask.fromJson(d.data())).toList();
  }

  /// Open tasks for one song, one-shot (the "before rehearsal" counter, #68).
  Future<int> openTaskCount(String songId, {String? bandId}) async {
    final snap = await _songDoc(songId, bandId: bandId)
        .collection('tasks')
        .where('status', whereIn: ['todo', 'doing', 'blocked'])
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ---- Versions ----

  Stream<List<SongVersion>> watchVersions(String songId, {String? bandId}) =>
      _songDoc(songId, bandId: bandId)
          .collection('versions')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs.map((d) => SongVersion.fromJson(d.data())).toList(),
          );

  Future<void> saveVersion(SongVersion version, {String? bandId}) =>
      _songDoc(version.songId, bandId: bandId)
          .collection('versions')
          .doc(version.id)
          .set(version.toJson());

  /// Marks [versionId] current and archives every other version in one batch.
  Future<void> setCurrentVersion(
    String songId,
    String versionId, {
    String? bandId,
  }) async {
    final col = _songDoc(songId, bandId: bandId).collection('versions');
    final snap = await col.get();
    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {
        'status': d.id == versionId ? 'current' : 'archived',
      });
    }
    await batch.commit();
  }
}
