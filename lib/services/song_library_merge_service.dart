import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/setlist.dart';
import '../models/song.dart';
import '../repositories/setlist_repository.dart';
import '../repositories/song_repository.dart';

class SongLibraryMergeService {
  SongLibraryMergeService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> merge({
    required String uid,
    required Song keeperBefore,
    required Song duplicate,
    required Song merged,
    required List<Setlist> setlists,
    required SongRepository songRepository,
    required SetlistRepository setlistRepository,
  }) async {
    await songRepository.saveSong(merged, uid: uid);

    final changedSetlists = <String>[];
    for (final setlist in setlists) {
      if (!setlist.songIds.contains(duplicate.id)) continue;
      final rewritten = <String>[];
      for (final id in setlist.songIds) {
        final replacement = id == duplicate.id ? keeperBefore.id : id;
        if (!rewritten.contains(replacement)) rewritten.add(replacement);
      }
      await setlistRepository.saveSetlist(
        setlist.copyWith(songIds: rewritten, updatedAt: DateTime.now()),
        uid: uid,
      );
      changedSetlists.add(setlist.id);
    }

    await songRepository.deleteSong(duplicate.id, uid: uid);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('song_merges')
        .add({
          'keeperId': keeperBefore.id,
          'duplicateId': duplicate.id,
          'keeperBefore': keeperBefore.toJson(),
          'duplicateBefore': duplicate.toJson(),
          'mergedSong': merged.toJson(),
          'rewrittenSetlistIds': changedSetlists,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<Set<String>> loadDismissedPairs(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('duplicate_dismissals')
        .get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> dismissPair(String uid, String pairKey) => _firestore
      .collection('users')
      .doc(uid)
      .collection('duplicate_dismissals')
      .doc(pairKey)
      .set({'createdAt': FieldValue.serverTimestamp()});
}
