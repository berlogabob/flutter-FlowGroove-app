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

  test('responseDeadline and venueType round-trip through JSON', () {
    final rehearsal = Rehearsal(
      id: 'r1',
      bandId: 'b1',
      createdBy: 'u1',
      title: 'Rehearsal',
      responseDeadline: DateTime(2026, 7, 3, 18),
      venueType: Rehearsal.venueCustom,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    final back = Rehearsal.fromJson(rehearsal.toJson());
    expect(back.responseDeadline, DateTime(2026, 7, 3, 18));
    expect(back.venueType, Rehearsal.venueCustom);
  });

  test('responseDeadline and venueType default to null when omitted', () {
    final rehearsal = Rehearsal(
      id: 'r1',
      bandId: 'b1',
      createdBy: 'u1',
      title: 'Rehearsal',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    final json = rehearsal.toJson();
    expect(json['responseDeadline'], isNull);
    expect(json['venueType'], isNull);

    final back = Rehearsal.fromJson(json);
    expect(back.responseDeadline, isNull);
    expect(back.venueType, isNull);
  });

  test('effectiveVenueType defaults from location for legacy rehearsals', () {
    final withLocation = Rehearsal(
      id: 'r1',
      bandId: 'b1',
      createdBy: 'u1',
      title: 'Rehearsal',
      location: 'Studio A',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
    expect(withLocation.effectiveVenueType, Rehearsal.venueCustom);

    final withoutLocation = withLocation.copyWith(location: null);
    expect(withoutLocation.effectiveVenueType, Rehearsal.venueUndecided);

    final explicit = withLocation.copyWith(venueType: Rehearsal.venueStudio);
    expect(explicit.effectiveVenueType, Rehearsal.venueStudio);
  });
}
