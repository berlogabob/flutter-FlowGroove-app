import '../models/setlist.dart';

/// Repository interface for Setlist data operations.
///
/// Defines the contract for setlist-related CRUD operations,
/// abstracting away the underlying data source (Firestore, cache, etc.).
///
/// This interface enables:
/// - Testability through dependency injection
/// - Swappable data sources
/// - Clear separation of concerns
abstract class SetlistRepository {
  /// Saves a setlist to the user's collection.
  Future<void> saveSetlist(Setlist setlist, {String? uid});

  /// Deletes a setlist from the user's collection.
  Future<void> deleteSetlist(String setlistId, {String? uid});

  /// Watches setlists for a user in real-time.
  Stream<List<Setlist>> watchSetlists(String uid);
}
