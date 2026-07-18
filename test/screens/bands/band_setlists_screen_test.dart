import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/bands/band_setlists_screen.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/routed_test_harness.dart';

void main() {
  group('BandSetlistsScreen', () {
    testWidgets(
      'renders shared band setlists and routes create with band scope',
      (tester) async {
        final band = _bandWithRole(BandMember.roleAdmin);
        final firebaseUser = MockUser();
        when(firebaseUser.uid).thenReturn('test-user-id');

        final router = await pumpRoutedTestApp(
          tester,
          initialLocation: '/main/bands/band-123/setlists',
          routes: _routesFor(band),
          overrides: [
            currentUserProvider.overrideWithValue(
              AsyncValue<User?>.data(firebaseUser),
            ),
            appUserProvider.overrideWith(
              () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
            ),
            bandSetlistsProvider.overrideWith(
              (ref, bandId) => Stream<List<Setlist>>.value([
                MockDataHelper.createMockSetlist(
                  id: 'setlist-1',
                  bandId: bandId,
                  name: 'Friday Gig',
                  songIds: ['song-1', 'song-2'],
                ),
              ]),
            ),
            bandSongsProvider.overrideWith(
              (ref, bandId) => Stream<List<Song>>.value([]),
            ),
          ],
        );
        await tester.pumpAndSettle();

        // This route tree isn't wrapped in MainShell, so there's no bottom
        // bar to render the title; the screen still publishes it locally.
        final scope = tester.widget<MenuItemsScope>(
          find.byType(MenuItemsScope),
        );
        expect(scope.title, 'Band 123 Setlists');
        expect(find.text('Friday Gig'), findsOneWidget);
        expect(find.text('2 songs'), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        final uri = currentRouterUri(router);
        expect(uri.path, '/main/setlists/create');
        expect(uri.queryParameters['bandId'], 'band-123');
        expect(uri.queryParameters['scope'], 'band');
        expect(find.text('route:create-setlist'), findsOneWidget);
      },
    );

    testWidgets('routes edit with band scope for editors', (tester) async {
      final band = _bandWithRole(BandMember.roleEditor);
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123/setlists',
        routes: _routesFor(band),
        overrides: [
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          bandSetlistsProvider.overrideWith(
            (ref, bandId) => Stream<List<Setlist>>.value([
              MockDataHelper.createMockSetlist(
                id: 'setlist-1',
                bandId: bandId,
                name: 'Friday Gig',
              ),
            ]),
          ),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value([]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      // Edit now lives in the card's overflow menu (the standalone pencil was
      // replaced by a single configurable quick-action icon).
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit setlist'));
      await tester.pumpAndSettle();

      expect(find.text('route:edit-setlist'), findsOneWidget);
      expect(
        find.text(
          'uri:/main/setlists/setlist-1/edit?bandId=band-123&scope=band',
        ),
        findsOneWidget,
      );
    });

    testWidgets('allows admins to delete shared band setlists', (tester) async {
      final band = _bandWithRole(BandMember.roleAdmin);
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      final firestore = MockFirestoreService();
      when(firestore.deleteBandSetlist(any, any)).thenAnswer((_) async {});

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123/setlists',
        routes: _routesFor(band),
        overrides: [
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          firestoreProvider.overrideWithValue(firestore),
          bandSetlistsProvider.overrideWith(
            (ref, bandId) => Stream<List<Setlist>>.value([
              MockDataHelper.createMockSetlist(
                id: 'setlist-1',
                bandId: bandId,
                name: 'Friday Gig',
              ),
            ]),
          ),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value([]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Friday Gig'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      verify(firestore.deleteBandSetlist('band-123', 'setlist-1')).called(1);
    });

    testWidgets('viewers can see setlists but cannot create or edit', (
      tester,
    ) async {
      final band = _bandWithRole(BandMember.roleViewer);
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123/setlists',
        routes: _routesFor(band),
        overrides: [
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          bandSetlistsProvider.overrideWith(
            (ref, bandId) => Stream<List<Setlist>>.value([
              MockDataHelper.createMockSetlist(
                id: 'setlist-1',
                bandId: bandId,
                name: 'Friday Gig',
              ),
            ]),
          ),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value([]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Friday Gig'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      // No edit pencil for viewers.
      expect(find.byIcon(Icons.edit), findsNothing);

      // Tap opens the read-only view for everyone (#128 parity with the
      // personal list) — viewers get a read path instead of a dead tap.
      await tester.tap(find.text('Friday Gig'));
      await tester.pumpAndSettle();

      expect(find.text('route:band-setlist-view'), findsOneWidget);
    });

    testWidgets('demo admins can read setlists but cannot modify them', (
      tester,
    ) async {
      final band = _bandWithRole(BandMember.roleAdmin);
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123/setlists',
        routes: _routesFor(band),
        overrides: [
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(
              AppUser(
                uid: 'test-user-id',
                email: 'demo@example.com',
                accessRole: 'demo',
                createdAt: DateTime(2024),
              ),
            ),
          ),
          bandSetlistsProvider.overrideWith(
            (ref, bandId) => Stream<List<Setlist>>.value([
              MockDataHelper.createMockSetlist(
                id: 'setlist-1',
                bandId: bandId,
                name: 'Demo Setlist',
              ),
            ]),
          ),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value([]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Demo Setlist'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('Edit setlist'), findsNothing);
    });

    testWidgets('shows a retry action when shared setlists fail to load', (
      tester,
    ) async {
      final band = _bandWithRole(BandMember.roleAdmin);
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123/setlists',
        routes: _routesFor(band),
        overrides: [
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          bandSetlistsProvider.overrideWith(
            (ref, bandId) => Stream<List<Setlist>>.error('permission-denied'),
          ),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value([]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('permission-denied'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

Band _bandWithRole(String role) {
  return MockDataHelper.createMockBand(
    id: 'band-123',
    name: 'Band 123',
    members: [
      BandMember(uid: 'test-user-id', role: role, displayName: 'Test User'),
    ],
  );
}

List<RouteBase> _routesFor(Band band) {
  return [
    GoRoute(
      path: '/main/bands/:id/setlists',
      name: 'band-setlists',
      builder: (context, state) => BandSetlistsScreen(band: band),
    ),
    GoRoute(
      path: '/main/setlists/create',
      name: 'create-setlist',
      builder: (context, state) => const TestRouteMarker('create-setlist'),
    ),
    GoRoute(
      path: '/main/setlists/:id/edit',
      name: 'edit-setlist',
      builder: (context, state) => const TestRouteMarker('edit-setlist'),
    ),
    GoRoute(
      path: '/main/setlists/:id',
      name: 'setlist-view',
      builder: (context, state) => const TestRouteMarker('setlist-view'),
    ),
    GoRoute(
      path: '/main/bands/:id/setlists/:setlistId',
      name: 'band-setlist-view',
      builder: (context, state) => const TestRouteMarker('band-setlist-view'),
    ),
  ];
}
