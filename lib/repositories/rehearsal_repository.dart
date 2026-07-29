import '../models/rehearsal.dart';

/// Repository interface for band rehearsal proposals/events and their votes.
///
/// All rehearsals are band-scoped (bands/{bandId}/rehearsals/{id}); votes live
/// in a per-member subcollection keyed by uid. Client writes are gated by
/// Firestore rules (no Cloud Function CRUD).
abstract class RehearsalRepository {
  /// Watches all rehearsals for a band in real-time.
  Stream<List<Rehearsal>> watchRehearsals(String bandId);

  /// Watches a single rehearsal in real-time.
  Stream<Rehearsal?> watchRehearsal(String bandId, String rehearsalId);

  /// Watches votes for a rehearsal, keyed by member uid.
  Stream<Map<String, RehearsalVote>> watchVotes(String bandId, String rehearsalId);

  /// Creates or updates a rehearsal.
  Future<void> saveRehearsal(Rehearsal rehearsal);

  /// Deletes a rehearsal.
  Future<void> deleteRehearsal(String bandId, String rehearsalId);

  /// Writes the current user's vote (docId == vote.uid).
  Future<void> saveVote(String bandId, String rehearsalId, RehearsalVote vote);
}
