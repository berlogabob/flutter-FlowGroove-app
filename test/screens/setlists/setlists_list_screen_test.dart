import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowgroove/screens/setlists/setlists_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mocks.dart';
import '../../helpers/routed_test_harness.dart';

void main() {
  group('SetlistsListScreen', () {
    late AppUser mockUser;

    List<dynamic> overridesFor({
      required Stream<List<Setlist>> setlists,
      Stream<List<Song>>? songs,
      Stream<List<Setlist>>? guestEvents,
    }) => [
      appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
      setlistsProvider.overrideWith((ref) => setlists),
      songsProvider.overrideWith(
        (ref) => songs ?? Stream<List<Song>>.value([]),
      ),
      // The screen also shows events this user is a guest on. Left unstubbed it
      // reaches the real collection-group query (and leaves a pending timer).
      guestEventsProvider.overrideWith(
        (ref) => guestEvents ?? Stream<List<Setlist>>.value([]),
      ),
    ];

    setUp(() {
      mockUser = MockDataHelper.createMockAppUser();
    });

    testWidgets('personal guest card opens an explicit owner-scoped route', (
      tester,
    ) async {
      Map<String, String>? query;
      final event = MockDataHelper.createMockSetlist(
        id: 'personal-event',
        name: 'Personal invitation',
      ).copyWith(bandId: '', ownerUid: 'event-owner');
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream.value([]),
          guestEvents: Stream.value([event]),
        ),
        routes: [
          GoRoute(
            path: '/main/setlists',
            name: 'setlists',
            builder: (_, _) => const SetlistsListScreen(),
          ),
          GoRoute(
            path: '/event',
            name: 'event-share',
            builder: (_, state) {
              query = state.uri.queryParameters;
              return const Scaffold(body: Text('Opened personal event'));
            },
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal invitation'));
      await tester.pumpAndSettle();
      expect(find.text('Opened personal event'), findsOneWidget);
      expect(query, {'ownerUid': 'event-owner', 'setlistId': 'personal-event'});
    });

    testWidgets('renders setlists screen with title and search', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      // No top app bar; only the shell's Setlists nav tab label names the
      // screen (root screens show no title anywhere else).
      expect(find.text('Setlists'), findsOneWidget);
      expect(find.text('Search setlists...'), findsOneWidget);
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('create FAB exposes an accessible action name', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpRoutedTestApp(
          tester,
          initialLocation: '/main/setlists',
          overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
        );
        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);
        expect(
          tester.getSemantics(fab).getSemanticsData().label,
          contains('Create Setlist'),
        );
        expect(find.byTooltip('Create Setlist'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('readonly users have no create FAB', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: [
          ...overridesFor(setlists: Stream<List<Setlist>>.value([])),
          canEditProvider.overrideWithValue(false),
        ],
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Create Setlist'),
        ),
        findsNothing,
      );
    });

    testWidgets('displays empty state when no setlists exist', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      expect(find.text('No setlists yet'), findsOneWidget);
      expect(find.text('Create a setlist for your next gig'), findsOneWidget);
      expect(find.text('Create Setlist'), findsOneWidget);
    });

    testWidgets('displays setlist cards with song counts and event dates', (
      tester,
    ) async {
      final setlists = [
        MockDataHelper.createMockSetlist(
          id: '1',
          name: 'Gig Setlist',
          songIds: ['s1', 's2', 's3'],
          eventDateTime: DateTime(2026, 5, 10),
        ),
        MockDataHelper.createMockSetlist(
          id: '2',
          name: 'Practice Setlist',
          songIds: ['s1'],
        ),
      ];

      // Card count is the RAW entry count, not filtered against the song
      // library: an entry whose songId doesn't resolve is still an entry
      // (setlist.effectiveItems), so only s1 needs to actually exist here
      // and "Gig Setlist" (3 songIds, only s1 resolves) still shows '3
      // songs' instead of undercounting to '1 song'.
      final songs = [MockDataHelper.createMockSong(id: 's1', title: 'Song 1')];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream<List<Setlist>>.value(setlists),
          songs: Stream<List<Song>>.value(songs),
        ),
      );

      expect(find.text('Gig Setlist'), findsOneWidget);
      expect(find.text('Practice Setlist'), findsOneWidget);
      // #86 rail: counts and event date share one line, dot-separated.
      expect(find.textContaining('3 songs'), findsOneWidget);
      expect(find.textContaining('1 song'), findsOneWidget);
      expect(find.textContaining('May 10, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play), findsWidgets);
    });

    testWidgets('filters setlists by name', (tester) async {
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Gig Setlist'),
        MockDataHelper.createMockSetlist(id: '2', name: 'Practice Setlist'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream<List<Setlist>>.value(setlists),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Gig');
      await tester.pump();

      expect(find.text('Gig Setlist'), findsOneWidget);
      expect(find.text('Practice Setlist'), findsNothing);
    });

    testWidgets('shows search empty state when no setlists match', (
      tester,
    ) async {
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Gig Setlist'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream<List<Setlist>>.value(setlists),
        ),
      );

      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Try searching for "missing"'), findsOneWidget);
    });

    testWidgets('tapping a setlist card opens the read-only view screen', (
      tester,
    ) async {
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Gig Setlist'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream<List<Setlist>>.value(setlists),
        ),
      );

      await tester.tap(find.text('Gig Setlist'));
      await tester.pumpAndSettle();

      // Note: pushNamed() from inside a StatefulShellBranch pushes onto the
      // branch's own nested Navigator and doesn't update
      // router.routeInformationProvider — the marker screen is the reliable
      // signal that the right route rendered (same pattern used for the
      // metronome push in songs_list_screen_test.dart).
      expect(find.text('route:setlist-view'), findsOneWidget);
      expect(find.text('route:edit-setlist'), findsNothing);
    });

    testWidgets('navigates to create setlist from FAB', (tester) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/setlists/create');
      expect(find.text('route:create-setlist'), findsOneWidget);
    });

    testWidgets('navigates to create setlist from empty state CTA', (
      tester,
    ) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Setlist'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/setlists/create');
      expect(find.text('route:create-setlist'), findsOneWidget);
    });

    testWidgets('shows loading indicator while setlists are loading', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: const Stream<List<Setlist>>.empty()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
