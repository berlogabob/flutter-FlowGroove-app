import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/bands/the_band_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/routed_test_harness.dart';

void main() {
  group('TheBandScreen', () {
    testWidgets('Setlist action opens create route with bandId', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final band = MockDataHelper.createMockBand(
        id: 'band-123',
        name: 'Band 123',
        members: [BandMember(uid: 'test-user-id', role: BandMember.roleAdmin)],
      );
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123',
        routes: [
          GoRoute(
            path: '/main/bands/:id',
            name: 'the-band',
            builder: (context, state) => TheBandScreen(band: band),
          ),
          GoRoute(
            path: '/main/setlists/create',
            name: 'create-setlist',
            builder: (context, state) =>
                const TestRouteMarker('create-setlist'),
          ),
        ],
        overrides: [
          // bandsProvider hits the real repository without this override;
          // the resulting error makes riverpod schedule retry timers that
          // trip the pending-timer invariant at teardown.
          bandsProvider.overrideWith((ref) => Stream<List<Band>>.value([band])),
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value([]),
          ),
          bandSetlistsProvider.overrideWith(
            (ref, bandId) => Stream<List<Setlist>>.value([]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Setlist'));
      await tester.pumpAndSettle();

      final uri = currentRouterUri(router);
      expect(uri.path, '/main/setlists/create');
      expect(uri.queryParameters['bandId'], 'band-123');
      expect(uri.queryParameters['scope'], 'band');
      expect(find.text('route:create-setlist'), findsOneWidget);
    });

    testWidgets('Setlists statistic opens shared band setlists route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final band = MockDataHelper.createMockBand(
        id: 'band-123',
        name: 'Band 123',
      );
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123',
        routes: [
          GoRoute(
            path: '/main/bands/:id',
            name: 'the-band',
            builder: (context, state) => TheBandScreen(band: band),
          ),
          GoRoute(
            path: '/main/bands/:id/setlists',
            name: 'band-setlists',
            builder: (context, state) => const TestRouteMarker('band-setlists'),
          ),
        ],
        overrides: [
          // bandsProvider hits the real repository without this override;
          // the resulting error makes riverpod schedule retry timers that
          // trip the pending-timer invariant at teardown.
          bandsProvider.overrideWith((ref) => Stream<List<Band>>.value([band])),
          currentUserProvider.overrideWithValue(
            AsyncValue<User?>.data(firebaseUser),
          ),
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value([]),
          ),
          bandSetlistsProvider.overrideWith(
            (ref, bandId) => Stream<List<Setlist>>.value([
              MockDataHelper.createMockSetlist(id: 'setlist-1'),
            ]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text('Setlists'));
      await tester.pumpAndSettle();

      final uri = currentRouterUri(router);
      expect(uri.path, '/main/bands/band-123/setlists');
      expect(find.text('route:band-setlists'), findsOneWidget);
    });
  });
}
