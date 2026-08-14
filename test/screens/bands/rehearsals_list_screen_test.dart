import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/bands/rehearsals/rehearsals_list_screen.dart';
import 'package:flowgroove/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  testWidgets('dims completed rehearsals and labels them Past', (tester) async {
    final band = Band(
      id: 'band-1',
      name: 'Test Band',
      createdBy: 'user-1',
      createdAt: DateTime(2024),
    );
    final now = DateTime.now();
    Rehearsal rehearsal(String id, DateTime start, DateTime end) => Rehearsal(
      id: id,
      bandId: band.id,
      createdBy: 'user-1',
      title: '$id rehearsal',
      candidateSlots: [
        CandidateSlot(id: 'slot-$id', startTime: start, endTime: end),
      ],
      status: Rehearsal.statusConfirmed,
      confirmedSlotId: 'slot-$id',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    await pumpAppWidget(
      tester,
      RehearsalsListScreen(band: band),
      overrides: [
        // Read-only viewer: the gate is now the canEditBandProvider family.
        canEditBandProvider(band.id).overrideWithValue(false),
        offlineProvider.overrideWithValue(false),
        bandRehearsalsProvider(band.id).overrideWith(
          (ref) => Stream.value([
            rehearsal(
              'Past',
              now.subtract(const Duration(days: 5, hours: 2)),
              now.subtract(const Duration(days: 5)),
            ),
            rehearsal(
              'Future',
              now.add(const Duration(days: 5)),
              now.add(const Duration(days: 5, hours: 2)),
            ),
          ]),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Past'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.6);
  });
}
