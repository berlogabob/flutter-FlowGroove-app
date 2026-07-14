import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/metronome_test_runtime.dart';
import '../../helpers/mocks.dart';
import '../../helpers/routed_test_harness.dart' show TestRouteMarker;

void main() {
  group('SetlistViewScreen', () {
    late Setlist setlist;
    late List<Song> songs;

    setUp(() {
      songs = [
        MockDataHelper.createMockSong(
          id: 's1',
          title: 'First Song',
          artist: 'Band A',
          ourKey: 'C',
          ourBPM: 120,
        ),
        MockDataHelper.createMockSong(
          id: 's2',
          title: 'Second Song',
          artist: 'Band B',
          ourKey: 'G',
          ourBPM: 90,
        ),
      ];
      setlist = MockDataHelper.createMockSetlist(
        id: 'setlist-1',
        name: 'Gig Setlist',
        songIds: ['s1', 's2'],
      );
    });

    /// Builds a minimal router with the view screen as home plus the two
    /// named routes it can push to, so `context.pushNamed` calls resolve
    /// without needing the full app router.
    Future<GoRouter> pumpView(
      WidgetTester tester, {
      bool canEdit = true,
    }) async {
      final router = GoRouter(
        initialLocation: '/view',
        routes: [
          GoRoute(
            path: '/view',
            name: 'view',
            builder: (context, state) =>
                SetlistViewScreen(setlist: setlist),
          ),
          GoRoute(
            path: '/setlists/:id/edit',
            name: 'edit-setlist',
            builder: (context, state) =>
                const TestRouteMarker('edit-setlist'),
          ),
          GoRoute(
            path: '/metronome',
            name: 'metronome',
            builder: (context, state) => const TestRouteMarker('metronome'),
          ),
        ],
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          songsProvider.overrideWith((ref) => Stream<List<Song>>.value(songs)),
          setlistsProvider.overrideWith(
            (ref) => Stream<List<Setlist>>.value([setlist]),
          ),
          canEditProvider.overrideWithValue(canEdit),
          ...buildMetronomeTestOverrides(overrideMetronomeProvider: true),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      return router;
    }

    testWidgets('shows the setlist name as the title and lists its songs', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Gig Setlist'), findsOneWidget);
      expect(find.text('First Song'), findsOneWidget);
      expect(find.text('Band A'), findsOneWidget);
      expect(find.text('Second Song'), findsOneWidget);
      expect(find.text('Band B'), findsOneWidget);
      // Key/BPM badges, mirroring the editor's row visuals.
      expect(find.text('C'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('has no editing affordances — no Save Changes, no drag handles', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Save Changes'), findsNothing);
      expect(find.text('Edit Setlist'), findsNothing);
      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('shows an Edit action that pushes the edit screen when canEdit', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('route:edit-setlist'), findsOneWidget);
    });

    testWidgets('hides the Edit action when canEdit is false', (
      tester,
    ) async {
      await pumpView(tester, canEdit: false);

      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('pushes the metronome screen from the primary action button', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('Open in Metronome'), findsOneWidget);

      await tester.tap(find.text('Open in Metronome'));
      await tester.pumpAndSettle();

      expect(find.text('route:metronome'), findsOneWidget);
    });
  });
}
