import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/song_lab.dart';
import '../services/pending_storage_deletes.dart';

/// Firestore access for Song Lab subcollections (#66) under a song doc:
/// `labEntries`, `tasks`, `versions` — for personal songs
/// (`users/{uid}/songs/{songId}`) and band songs
/// (`bands/{bandId}/songs/{songId}`), selected by `bandId`.
///
/// ponytail: single concrete class, no interface — one implementation exists.
class FirestoreLabRepository {
  FirestoreLabRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    PendingStorageDeletes? pendingStorageDeletes,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _pendingStorageDeletes =
           pendingStorageDeletes ?? PendingStorageDeletes();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final PendingStorageDeletes _pendingStorageDeletes;

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
      ? _firestore
            .collection('bands')
            .doc(bandId)
            .collection('songs')
            .doc(songId)
      : _firestore
            .collection('users')
            .doc(_uid)
            .collection('songs')
            .doc(songId);

  // ---- Entries ----

  Stream<List<SongLabEntry>> watchEntries(String songId, {String? bandId}) =>
      _songDoc(songId, bandId: bandId)
          .collection('labEntries')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs.map((d) => SongLabEntry.fromJson(d.data())).toList(),
          );

  /// Reconciles uncertain writes against the server; errors are not absence.
  Future<SongLabEntry?> readEntryFromServer(
    String songId,
    String entryId, {
    String? bandId,
  }) async {
    final snapshot = await _songDoc(songId, bandId: bandId)
        .collection('labEntries')
        .doc(entryId)
        .get(const GetOptions(source: Source.server));
    // Source.server still overlays local pending writes (latency compensation).
    if (snapshot.metadata.hasPendingWrites || snapshot.metadata.isFromCache) {
      throw StateError('Entry is not confirmed by the server');
    }
    if (!snapshot.exists) return null;
    return SongLabEntry.fromJson(snapshot.data()!);
  }

  /// Searches by URL because linked inbox recordings keep their original path.
  /// Errors (including denied collection-group reads) must not imply absence.
  Future<bool> isStorageUrlReferenced(String url) async {
    final entries = _firestore.collectionGroup('labEntries');
    for (final query in [
      entries.where('attachmentIds', arrayContains: url),
      entries.where('midiSong.fileUrl', isEqualTo: url),
    ]) {
      final snapshot = await query.get(const GetOptions(source: Source.server));
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        throw StateError('References are not confirmed by the server');
      }
      for (final doc in snapshot.docs) {
        final path = doc.reference.path.split('/');
        if (path.length != 6 ||
            path[2] != 'songs' ||
            path[4] != 'labEntries' ||
            (path[0] != 'bands' && path[0] != 'users') ||
            (path[0] == 'users' && path[1] != _uid)) {
          throw StateError('Cannot confirm entry ownership');
        }
        final entry = await readEntryFromServer(
          path[3],
          path[5],
          bandId: path[0] == 'bands' ? path[1] : null,
        );
        if (entry != null &&
            (entry.attachmentIds.contains(url) ||
                entry.midiSong?.fileUrl == url)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    // Every restore path must preserve the files before publishing the entry.
    final urls = {
      ?entry.midiSong?.fileUrl,
      if (entry.type == LabEntryType.recording) ...entry.attachmentIds,
    };
    for (final url in urls) {
      await _pendingStorageDeletes.cancel(url);
    }
    await _songDoc(
      entry.songId,
      bandId: bandId,
    ).collection('labEntries').doc(entry.id).set({
      ...entry.toJson(),
      // Empty notes are omitted by toJson, but must clear a merged document.
      if (entry.notes.isEmpty) 'notes': FieldValue.delete(),
      // A merged save must clear a removed tempo grid in Firestore too.
      if (entry.type == LabEntryType.recording) 'grid': entry.grid?.toJson(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteEntry(
    String songId,
    String entryId, {
    String? bandId,
  }) async {
    final doc = _songDoc(
      songId,
      bandId: bandId,
    ).collection('labEntries').doc(entryId);
    final data = (await doc.get()).data();
    final url = data == null
        ? null
        : SongLabEntry.fromJson(data).midiSong?.fileUrl;
    await doc.delete();
    if (url != null) {
      await _pendingStorageDeletes.enqueue(url);
      unawaited(_pendingStorageDeletes.flushAfter(url, undoGracePeriod));
    }
  }

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
          .set(task.toJson(), SetOptions(merge: true));

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
          .set(version.toJson(), SetOptions(merge: true));

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
