import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/bands/band_setlists_screen.dart';
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

        expect(find.text('Band 123 Setlists'), findsOneWidget);
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
      await tester.tap(find.byTooltip('Edit setlist'));
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

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123/setlists',
        routes: _routesFor(band),
        overrides: [
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
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

      await tester.tap(find.text('Friday Gig'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/bands/band-123/setlists');
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
  ];
}
