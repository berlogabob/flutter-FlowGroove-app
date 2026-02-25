import '../models/song.dart';

/// Repository interface for Song data operations.
///
/// Defines the contract for song-related CRUD operations,
/// abstracting away the underlying data source (Firestore, cache, etc.).
///
/// This interface enables:
/// - Testability through dependency injection
/// - Swappable data sources
/// - Clear separation of concerns
abstract class SongRepository {
  /// Saves a song to the user's personal collection.
  Future<void> saveSong(Song song, {String? uid});

  /// Deletes a song from the user's personal collection.
  Future<void> deleteSong(String songId, {String? uid});

  /// Updates a song in the user's personal collection.
  Future<void> updateSong(Song song, {String? uid});

  /// Watches songs for a user in real-time.
  Stream<List<Song>> watchSongs(String uid);

  /// Adds a song to a band's song collection.
  Future<void> addSongToBand({
    required Song song,
    required String bandId,
    String? contributorId,
    String? contributorName,
  });

  /// Add an existing song to a band by song ID.
  Future<void> addSongToBandById(String songId, String bandId);

  /// Saves a song to a band's collection.
  Future<void> saveBandSong(Song song, String bandId);

  /// Watches songs for a specific band.
  Stream<List<Song>> watchBandSongs(String bandId);

  /// Deletes a song from a band's collection.
  Future<void> deleteBandSong(String bandId, String songId);

  /// Updates a song in a band's collection.
  Future<void> updateBandSong(Song song, String bandId);
}
