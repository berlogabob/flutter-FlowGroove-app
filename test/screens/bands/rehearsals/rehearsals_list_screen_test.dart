import 'package:flowgroove/models/rehearsal.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/bands/rehearsals/rehearsals_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/routed_test_harness.dart';

void main() {
  final band = MockDataHelper.createMockBand(id: 'band-123');

  Future<void> pumpScreen(WidgetTester tester, {required bool canEdit}) async {
    await pumpRoutedTestApp(
      tester,
      initialLocation: '/rehearsals',
      overrides: [
        bandRehearsalsProvider(
          band.id,
        ).overrideWith((ref) => Stream<List<Rehearsal>>.value([])),
        canEditBandProvider(band.id).overrideWithValue(canEdit),
      ],
      routes: [
        GoRoute(
          path: '/rehearsals',
          builder: (_, _) => RehearsalsListScreen(band: band),
        ),
        GoRoute(
          path: '/bands/:id/rehearsals/create',
          name: 'create-rehearsal',
          builder: (_, state) {
            expect(state.extra, same(band));
            return Scaffold(
              body: Text('Create for ${state.pathParameters['id']}'),
            );
          },
        ),
      ],
    );
  }

  testWidgets('proposal FAB names its action and preserves band scope', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpScreen(tester, canEdit: true);
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(
        tester.getSemantics(fab).getSemanticsData().label,
        contains('Propose rehearsal'),
      );
      expect(find.byTooltip('Propose rehearsal'), findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.text('Create for band-123'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('readonly users cannot propose a rehearsal', (tester) async {
    await pumpScreen(tester, canEdit: false);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Propose rehearsal'), findsNothing);
    expect(find.text('Proposed rehearsals will appear here'), findsOneWidget);
  });
}
