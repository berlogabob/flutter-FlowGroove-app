import 'package:flowgroove/models/rehearsal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rehearsal.toJson serializes candidateSlots to maps, not Dart objects '
      '(Firestore rejected Instance of CandidateSlot)', () {
    final rehearsal = Rehearsal(
      id: 'r1',
      bandId: 'b1',
      createdBy: 'u1',
      title: 'Rehearsal',
      candidateSlots: [
        CandidateSlot(
          id: 's1',
          startTime: DateTime(2026, 7, 2, 19),
          endTime: DateTime(2026, 7, 2, 21),
        ),
      ],
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    final json = rehearsal.toJson();
    final slots = json['candidateSlots'] as List;
    expect(slots.single, isA<Map<String, dynamic>>());

    // Round-trip survives.
    final back = Rehearsal.fromJson(json);
    expect(back.candidateSlots.single.id, 's1');
    expect(back.candidateSlots.single.startTime, DateTime(2026, 7, 2, 19));
  });
}
