import '../models/rehearsal.dart';

/// Score for a single candidate slot given the collected votes.
class RehearsalSlotScore {
  RehearsalSlotScore({
    required this.slotId,
    required this.score,
    required this.blocked,
    required this.blockingUids,
  });

  final String slotId;

  /// Higher is better. Meaningless when [blocked] is true.
  final int score;

  /// True if at least one required member answered "can't" for this slot.
  final bool blocked;

  /// Required members who answered "can't" for this slot.
  final List<String> blockingUids;
}

/// Pure best-slot scoring. See BLOG/spec:
///   required can +100, required maybe +40, optional can +10, optional maybe +4.
///   Any required "can't" blocks the slot. Organizer still confirms manually.
///
/// [votes] maps memberUid -> that member's vote.
List<RehearsalSlotScore> scoreSlots(
  Rehearsal rehearsal,
  Map<String, RehearsalVote> votes,
) {
  final required = rehearsal.requiredMemberUids;
  final optional = rehearsal.optionalMemberUids;

  return rehearsal.candidateSlots.map((slot) {
    var score = 0;
    final blockingUids = <String>[];

    for (final uid in required) {
      switch (votes[uid]?.answers[slot.id]) {
        case RehearsalVote.answerCan:
          score += 100;
        case RehearsalVote.answerMaybe:
          score += 40;
        case RehearsalVote.answerCant:
          blockingUids.add(uid);
        default:
          break; // no answer yet: neutral
      }
    }
    for (final uid in optional) {
      switch (votes[uid]?.answers[slot.id]) {
        case RehearsalVote.answerCan:
          score += 10;
        case RehearsalVote.answerMaybe:
          score += 4;
        default:
          break;
      }
    }

    return RehearsalSlotScore(
      slotId: slot.id,
      score: score,
      blocked: blockingUids.isNotEmpty,
      blockingUids: blockingUids,
    );
  }).toList();
}

/// The single best slot to suggest, or null if there are no candidate slots.
/// Blocked slots only win if every slot is blocked (then the least-bad by score).
RehearsalSlotScore? bestSlot(
  Rehearsal rehearsal,
  Map<String, RehearsalVote> votes,
) {
  final scores = scoreSlots(rehearsal, votes);
  if (scores.isEmpty) return null;

  final unblocked = scores.where((s) => !s.blocked).toList();
  final pool = unblocked.isNotEmpty ? unblocked : scores;
  pool.sort((a, b) => b.score.compareTo(a.score));
  return pool.first;
}
