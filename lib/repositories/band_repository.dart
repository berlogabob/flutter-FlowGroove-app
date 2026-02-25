import '../models/band.dart';

/// Repository interface for Band data operations.
///
/// Defines the contract for band-related CRUD operations,
/// abstracting away the underlying data source (Firestore, cache, etc.).
///
/// This interface enables:
/// - Testability through dependency injection
/// - Swappable data sources
/// - Clear separation of concerns
abstract class BandRepository {
  /// Saves a band reference to the user's collection.
  Future<void> saveBand(Band band, {String? uid});

  /// Deletes a band reference from the user's collection.
  Future<void> deleteBand(String bandId, {String? uid});

  /// Watches bands for a user in real-time.
  Stream<List<Band>> watchBands(String uid);

  /// Saves a band to the global 'bands' collection.
  Future<void> saveBandToGlobal(Band band);

  /// Gets a band by invite code from global collection.
  Future<Band?> getBandByInviteCode(String code);

  /// Checks if invite code is already taken.
  Future<bool> isInviteCodeTaken(String code);

  /// Adds user reference to a band (for joining).
  Future<void> addUserToBand(String bandId, {String? userId});

  /// Removes user reference from a band (for leaving).
  Future<void> removeUserFromBand(String bandId, {String? userId});
}
