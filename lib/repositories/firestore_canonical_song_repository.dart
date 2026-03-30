import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/canonical_song.dart';
import 'canonical_song_repository.dart';

/// Firestore implementation of [CanonicalSongRepository]
/// 
/// Provides Firestore-based data access for canonical songs.
/// Includes query optimization, error handling, and data validation.
class FirestoreCanonicalSongRepository implements CanonicalSongRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'canonical_songs';

  FirestoreCanonicalSongRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  @override
  Future<CanonicalSong?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      
      if (!doc.exists) return null;
      
      return CanonicalSong.fromJson(doc.data()!);
    } catch (e) {
      throw RepositoryException(
        'Failed to get canonical song by ID: $id',
        originalError: e,
      );
    }
  }

  @override
  Future<CanonicalSong?> getByMusicBrainzId(String mbId) async {
    try {
      final snapshot = await _collection
          .where('musicBrainzId', isEqualTo: mbId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return CanonicalSong.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw RepositoryException(
        'Failed to get canonical song by MusicBrainz ID: $mbId',
        originalError: e,
      );
    }
  }

  @override
  Future<CanonicalSong?> getByISRC(String isrc) async {
    try {
      final snapshot = await _collection
          .where('isrc', isEqualTo: isrc)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return CanonicalSong.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw RepositoryException(
        'Failed to get canonical song by ISRC: $isrc',
        originalError: e,
      );
    }
  }

  @override
  Future<List<CanonicalSong>> search({
    required String query,
    int limit = 20,
  }) async {
    try {
      // Normalize query
      final normalizedQuery = query.toLowerCase().trim();
      
      // Use prefix search on normalized title
      final snapshot = await _collection
          .where('normalizedTitle', isGreaterThanOrEqualTo: normalizedQuery)
          .where('normalizedTitle', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CanonicalSong.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw RepositoryException(
        'Failed to search canonical songs: $query',
        originalError: e,
      );
    }
  }

  @override
  Future<List<CanonicalSong>> searchByTitle({
    required String titlePrefix,
    int limit = 20,
  }) async {
    try {
      final normalizedPrefix = titlePrefix.toLowerCase().trim();
      
      final snapshot = await _collection
          .where('normalizedTitle', isGreaterThanOrEqualTo: normalizedPrefix)
          .where('normalizedTitle', isLessThanOrEqualTo: '$normalizedPrefix\uf8ff')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CanonicalSong.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw RepositoryException(
        'Failed to search by title prefix: $titlePrefix',
        originalError: e,
      );
    }
  }

  @override
  Future<CanonicalSong> create(CanonicalSong song) async {
    try {
      final docRef = await _collection.add(song.toJson());
      
      return song.copyWith(id: docRef.id);
    } catch (e) {
      throw RepositoryException(
        'Failed to create canonical song: ${song.title}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> update(CanonicalSong song) async {
    try {
      await _collection.doc(song.id).update({
        ...song.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw RepositoryException(
        'Failed to update canonical song: ${song.id}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw RepositoryException(
        'Failed to delete canonical song: $id',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> exists(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      return doc.exists;
    } catch (e) {
      throw RepositoryException(
        'Failed to check if canonical song exists: $id',
        originalError: e,
      );
    }
  }

  @override
  Future<int> count() async {
    try {
      // Note: This requires an aggregate query (Firestore 2023+)
      // For older versions, you'll need to maintain a manual count
      final snapshot = await _collection.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw RepositoryException(
        'Failed to count canonical songs',
        originalError: e,
      );
    }
  }

  /// Cache a song from MusicBrainz
  /// 
  /// Checks if song exists by MusicBrainz ID first.
  /// If exists, returns existing song.
  /// If not, creates new song.
  Future<CanonicalSong> cacheFromMusicBrainz(CanonicalSong song) async {
    if (song.musicBrainzId != null) {
      final existing = await getByMusicBrainzId(song.musicBrainzId!);
      if (existing != null) {
        return existing;
      }
    }

    return await create(song);
  }

  /// Batch create/update multiple songs
  /// 
  /// More efficient than individual operations.
  Future<void> batchCreate(List<CanonicalSong> songs) async {
    try {
      final batch = _firestore.batch();

      for (final song in songs) {
        final docRef = _collection.doc();
        final songWithId = song.copyWith(id: docRef.id);
        batch.set(docRef, songWithId.toJson());
      }

      await batch.commit();
    } catch (e) {
      throw RepositoryException(
        'Failed to batch create canonical songs',
        originalError: e,
      );
    }
  }
}

/// Exception thrown by repository operations
class RepositoryException implements Exception {
  final String message;
  final dynamic originalError;

  const RepositoryException(
    this.message, {
    this.originalError,
  });

  @override
  String toString() {
    if (originalError != null) {
      return 'RepositoryException: $message - Original: $originalError';
    }
    return 'RepositoryException: $message';
  }
}
