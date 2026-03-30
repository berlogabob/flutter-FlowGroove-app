import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/canonical_song.dart';

/// Repository interface for canonical song data access
/// 
/// Provides abstraction over Firestore for canonical song operations.
/// This makes testing easier and allows swapping implementations.
/// 
/// Usage:
/// ```dart
/// final repo = CanonicalSongRepository();
/// final song = await repo.getById('song-id');
/// final results = await repo.search(query: 'bohemian');
/// ```
abstract class CanonicalSongRepository {
  /// Get a canonical song by ID
  /// 
  /// Returns `null` if not found.
  Future<CanonicalSong?> getById(String id);

  /// Get a canonical song by MusicBrainz ID
  /// 
  /// Returns `null` if not found.
  Future<CanonicalSong?> getByMusicBrainzId(String mbId);

  /// Get a canonical song by ISRC
  /// 
  /// Returns `null` if not found.
  Future<CanonicalSong?> getByISRC(String isrc);

  /// Search canonical songs by query
  /// 
  /// [query] - Search query (title, artist, or both)
  /// [limit] - Maximum results to return (default: 20)
  /// 
  /// Returns list of matching songs sorted by relevance.
  Future<List<CanonicalSong>> search({
    required String query,
    int limit = 20,
  });

  /// Search by title prefix
  /// 
  /// [titlePrefix] - Title prefix to search for
  /// [limit] - Maximum results
  Future<List<CanonicalSong>> searchByTitle({
    required String titlePrefix,
    int limit = 20,
  });

  /// Create a new canonical song
  /// 
  /// Returns the created song with generated ID.
  Future<CanonicalSong> create(CanonicalSong song);

  /// Update an existing canonical song
  /// 
  /// Throws if song doesn't exist.
  Future<void> update(CanonicalSong song);

  /// Delete a canonical song
  /// 
  /// Throws if song doesn't exist.
  Future<void> delete(String id);

  /// Check if a song exists by ID
  Future<bool> exists(String id);

  /// Get total count of canonical songs
  Future<int> count();
}
