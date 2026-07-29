import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/utils/rehearsal_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

CandidateSlot _slot(String id) => CandidateSlot(
  id: id,
  startTime: DateTime(2026, 7, 4, 19),
  endTime: DateTime(2026, 7, 4, 21),
);

RehearsalVote _vote(String uid, Map<String, String> answers) =>
    RehearsalVote(uid: uid, answers: answers, updatedAt: DateTime(2026));

Rehearsal _rehearsal({
  required List<String> required,
  List<String> optional = const [],
}) => Rehearsal(
  id: 'r1',
  bandId: 'b1',
  createdBy: 'u0',
  title: 'Test',
  candidateSlots: [_slot('a'), _slot('b')],
  requiredMemberUids: required,
  optionalMemberUids: optional,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('a required "can\'t" blocks the slot; unblocked slot wins', () {
    final r = _rehearsal(required: ['drummer']);
    final votes = {
      'drummer': _vote('drummer', {'a': 'cant', 'b': 'can'}),
    };

    final scores = {for (final s in scoreSlots(r, votes)) s.slotId: s};
    expect(scores['a']!.blocked, isTrue);
    expect(scores['b']!.blocked, isFalse);
    expect(bestSlot(r, votes)!.slotId, 'b');
  });

  test('more optional availability wins between two unblocked slots', () {
    final r = _rehearsal(required: ['drummer'], optional: ['guitar', 'keys']);
    final votes = {
      'drummer': _vote('drummer', {'a': 'can', 'b': 'can'}),
      'guitar': _vote('guitar', {'a': 'can', 'b': 'cant'}),
      'keys': _vote('keys', {'a': 'can', 'b': 'cant'}),
    };

    expect(bestSlot(r, votes)!.slotId, 'a');
  });

  test('all-blocked falls back to least-bad by score', () {
    final r = _rehearsal(required: ['drummer'], optional: ['guitar']);
    final votes = {
      'drummer': _vote('drummer', {'a': 'cant', 'b': 'cant'}),
      'guitar': _vote('guitar', {'a': 'can', 'b': 'cant'}),
    };

    final best = bestSlot(r, votes)!;
    expect(best.blocked, isTrue);
    expect(best.slotId, 'a'); // higher optional score
  });
}
