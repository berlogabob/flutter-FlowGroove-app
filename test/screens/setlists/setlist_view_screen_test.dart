import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/main_shell.dart';
import 'package:flowgroove/screens/setlists/create_setlist_screen.dart'
    show SetlistStorageScope;
import 'package:flowgroove/screens/setlists/setlist_view_screen.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/metronome_test_runtime.dart';
import '../../helpers/mocks.dart';
import '../../helpers/routed_test_harness.dart'
    show TestAppUserNotifier, TestRouteMarker;

void main() {
  group('SetlistViewScreen', () {
    late Setlist setlist;
    late List<Song> songs;

    /// Query parameters the edit route was actually reached with. The editor
    /// picks its storage collection from these, so navigating without them
    /// silently saves a band setlist into the personal one.
    late Map<String, String> editQuery;

    setUp(() {
      editQuery = const {};
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

    /// Builds a minimal router mirroring production: the view screen is a
    /// pushed child of the setlists branch inside the real [MainShell], so
    /// the shell's pushed-mode bottom bar ([← Back] [setlist name] [⋮])
    /// renders. Portrait viewport, because the bottom bar only exists in
    /// portrait (landscape uses the rail).
    Future<GoRouter> pumpView(
      WidgetTester tester, {
      bool canEdit = true,
      String? bandId,
      SetlistStorageScope storageScope = SetlistStorageScope.personal,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      MenuScopeRegistry.reset();

      final router = GoRouter(
        initialLocation: '/main/setlists/view/${setlist.id}',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                MainShell(navigationShell: navigationShell),
            branches: [
              for (final root in const [
                '/main/home',
                '/main/songs',
                '/main/bands',
              ])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: root,
                      builder: (context, state) =>
                          TestRouteMarker(root.split('/').last),
                    ),
                  ],
                ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/main/setlists',
                    name: 'setlists',
                    builder: (context, state) =>
                        const TestRouteMarker('setlists'),
                    routes: [
                      GoRoute(
                        path: 'view/:id',
                        name: 'view',
                        builder: (context, state) => SetlistViewScreen(
                          setlist: setlist,
                          bandId: bandId,
                          storageScope: storageScope,
                        ),
                      ),
                      GoRoute(
                        path: ':id/edit',
                        name: 'edit-setlist',
                        builder: (context, state) {
                          editQuery = state.uri.queryParameters;
                          return const TestRouteMarker('edit-setlist');
                        },
                      ),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/main/profile',
                    name: 'profile',
                    builder: (context, state) =>
                        const TestRouteMarker('profile'),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/main/metronome',
            name: 'metronome',
            builder: (context, state) => const TestRouteMarker('metronome'),
          ),
        ],
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          // The shell's DemoModeBanner watches appUserProvider; without an
          // override the real notifier throws (no Firebase in tests) and
          // Riverpod's retry timer trips the pending-timer check.
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          songsProvider.overrideWith((ref) => Stream<List<Song>>.value(songs)),
          // With a bandId the screen reads the band's songs and setlists
          // instead of the personal ones; unoverridden they error and
          // Riverpod's retry timer trips the pending-timer check.
          bandSongsProvider.overrideWith(
            (ref, id) => Stream<List<Song>>.value(songs),
          ),
          bandSetlistsProvider.overrideWith(
            (ref, id) => Stream<List<Setlist>>.value([setlist]),
          ),
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

      // The setlist name is published as the bottom bar's title.
      final scope = tester.widget<MenuItemsScope>(find.byType(MenuItemsScope));
      expect(scope.title, 'Gig Setlist');
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

    testWidgets(
      'has no editing affordances — no Save Changes, no drag handles',
      (tester) async {
        await pumpView(tester);

        expect(find.text('Save Changes'), findsNothing);
        expect(find.text('Edit Setlist'), findsNothing);
        expect(find.byIcon(Icons.drag_handle), findsNothing);
        expect(find.byType(Dismissible), findsNothing);
      },
    );

    testWidgets(
      'shows an Edit action that pushes the edit screen when canEdit',
      (tester) async {
        await pumpView(tester);

        // Edit moved into the bottom bar's Menu sheet.
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();

        expect(find.text('Edit Setlist'), findsOneWidget);

        await tester.tap(find.text('Edit Setlist'));
        await tester.pumpAndSettle();

        expect(find.text('route:edit-setlist'), findsOneWidget);
      },
    );

    testWidgets('carries bandId and scope into the editor for a band setlist', (
      tester,
    ) async {
      // Regression: without these the editor defaults to personal scope and
      // writes users/{uid}/setlists/{id}. The band document is never touched,
      // the personal list hides the stray (it filters out a non-empty bandId),
      // and the user's edit vanishes with no error.
      await pumpView(
        tester,
        bandId: 'band-1',
        storageScope: SetlistStorageScope.band,
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Setlist'));
      await tester.pumpAndSettle();

      expect(editQuery['bandId'], 'band-1');
      expect(editQuery['scope'], SetlistStorageScope.band.name);
    });

    testWidgets('omits bandId for a personal setlist', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Setlist'));
      await tester.pumpAndSettle();

      expect(editQuery.containsKey('bandId'), isFalse);
      expect(editQuery['scope'], SetlistStorageScope.personal.name);
    });

    testWidgets('hides the Edit action when canEdit is false', (tester) async {
      await pumpView(tester, canEdit: false);

      // Read actions (Metronome/Share/Export) are always present, so the ⋮ Menu
      // still shows; only the editor-only Edit/Event kit are hidden.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Edit Setlist'), findsNothing);
      expect(find.text('Open in Metronome'), findsOneWidget);
    });

    testWidgets('pushes the metronome screen from the Menu', (tester) async {
      await pumpView(tester);

      // Open in Metronome moved from a primary button into the ⋮ Menu sheet.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Open in Metronome'), findsOneWidget);

      await tester.tap(find.text('Open in Metronome'));
      await tester.pumpAndSettle();

      expect(find.text('route:metronome'), findsOneWidget);
    });
  });
}
