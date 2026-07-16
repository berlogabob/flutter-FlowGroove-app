import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/setlist.dart';
import '../models/song.dart';
import '../repositories/setlist_repository.dart';
import '../repositories/song_repository.dart';

class SongLibraryMergeService {
  SongLibraryMergeService({required this._firestore});

  final FirebaseFirestore _firestore;

  Future<String?> mergeImportedSong({
    required String uid,
    required Song original,
    required Song merged,
    required List<Song> sources,
    required SongRepository songRepository,
  }) async {
    await songRepository.saveSong(merged, uid: uid);
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('song_merges')
          .add({
            'type': 'csv_import',
            'keeperId': original.id,
            'keeperBefore': original.toJson(),
            'mergedSong': merged.toJson(),
            'importedSources': sources.map((song) => song.toJson()).toList(),
            'createdAt': FieldValue.serverTimestamp(),
          });
      return null;
    } catch (error) {
      return 'Updated "${merged.title}", but could not record merge history: $error';
    }
  }

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
      // effectiveItems covers both legacy (songIds-only) and modern
      // (items-based) setlists, so this catches the duplicate either way.
      final containsDuplicate = setlist.effectiveItems.any(
        (item) => item.songId == duplicate.id,
      );
      if (!containsDuplicate) continue;

      // Rewrite items (the source of truth once a setlist has any) — this is
      // what toJson()/effectiveItems actually persist. Rewriting only
      // songIds here is a no-op for a setlist that already has items, since
      // effectiveItems prefers items over songIds.
      final seenItemSongIds = <String>{};
      final rewrittenItems = <SetlistItem>[];
      for (final item in setlist.items) {
        final newSongId = item.songId == duplicate.id
            ? keeperBefore.id
            : item.songId;
        if (!seenItemSongIds.add(newSongId)) continue; // dedupe, keep first
        rewrittenItems.add(
          newSongId == item.songId ? item : item.copyWith(songId: newSongId),
        );
      }

      // Keep the legacy songIds rewrite too: for a setlist whose items are
      // still empty, effectiveItems falls back to songIds, so this is what
      // actually gets persisted for those.
      final rewrittenSongIds = <String>[];
      for (final id in setlist.songIds) {
        final replacement = id == duplicate.id ? keeperBefore.id : id;
        if (!rewrittenSongIds.contains(replacement)) {
          rewrittenSongIds.add(replacement);
        }
      }

      await setlistRepository.saveSetlist(
        setlist.copyWith(
          items: rewrittenItems,
          songIds: rewrittenSongIds,
          updatedAt: DateTime.now(),
        ),
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
          'type': 'library_merge',
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
