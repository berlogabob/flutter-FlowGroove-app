import '../models/event_suggestion.dart';
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

  /// Saves a setlist to a band's shared collection.
  Future<void> saveBandSetlist(Setlist setlist, String bandId);

  /// Deletes a setlist from a band's shared collection.
  Future<void> deleteBandSetlist(String bandId, String setlistId);

  /// Writes ONE area of the event kit (`stage` / `rider` / `people`) using a
  /// dotted field path, leaving every other field of the setlist untouched.
  ///
  /// This is the only supported way to save event-kit changes. The areas have
  /// separate editors and separate permissions — a sound engineer may be moving
  /// speakers around while the band reorders the set — so a whole-document
  /// write would silently destroy whichever change landed first. The security
  /// rules rely on this too: a guest's write is only allowed if it touches
  /// nothing but their own area.
  ///
  /// [bandId] null means the caller's personal setlist.
  Future<void> updateEventKitArea({
    required String setlistId,
    required String area,
    required Object? value,
    String? bandId,
    String? uid,
  });

  /// Watches setlists for a band in real-time.
  Stream<List<Setlist>> watchBandSetlists(String bandId);

  /// Watches events [uid] is a guest on, across every band, without being a
  /// member of any of them.
  Stream<List<Setlist>> watchGuestEvents(String uid);

  /// Suggestions people made about ONE event, for members or its owner.
  ///
  /// The subcollection is readable by band members or the personal owner, so this is the
  /// organizers' view of the inbox. A guest sees their own through
  /// `getEventView.mySuggestions` — an anonymous link holder has no uid for a
  /// security rule to match on.
  Stream<List<EventSuggestion>> watchSetlistSuggestions(
    String? bandId,
    String setlistId, {
    String? ownerUid,
  });
}
