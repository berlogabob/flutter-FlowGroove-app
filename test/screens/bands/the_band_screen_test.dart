import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/bands/the_band_screen.dart';
import 'package:flowgroove/services/firestore_service.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/routed_test_harness.dart';

class _RecordingFirestore implements FirestoreService {
  final calls = <String>[];

  @override
  Future<void> saveBandToGlobal(Band band) async =>
      calls.add('global:${band.name}');

  @override
  Future<void> saveBand(Band band, {String? uid}) async =>
      calls.add('user:${band.name}');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('TheBandScreen', () {
    testWidgets('rename saves the shared band too and closes only the dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      MenuScopeRegistry.reset();

      final band = MockDataHelper.createMockBand(
        id: 'band-123',
        name: 'Band 123',
        members: [BandMember(uid: 'test-user-id', role: BandMember.roleAdmin)],
      );
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');
      final fs = _RecordingFirestore();

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123',
        routes: [
          GoRoute(
            path: '/main/bands/:id',
            name: 'the-band',
            builder: (context, state) => TheBandScreen(band: band),
          ),
        ],
        overrides: [
          firestoreProvider.overrideWithValue(fs),
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

      final menu = MenuScopeRegistry.forLocation('/main/bands/band-123')!;
      menu.items.firstWhere((i) => i.label == 'Edit Band Name').onTap!();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fs.calls, ['global:Renamed', 'user:Renamed']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TheBandScreen), findsOneWidget);
    });

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

      // Pushed (not go'd) so saving returns to the band; a pushed route
      // doesn't move currentRouterUri, so assert on the rendered marker.
      expect(find.text('route:create-setlist'), findsOneWidget);
      expect(
        find.text('uri:/main/setlists/create?bandId=band-123&scope=band'),
        findsOneWidget,
      );

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Band 123'), findsWidgets);
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

      await pumpRoutedTestApp(
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

      // Pushed (not go'd) so Back returns to the band detail; a pushed route
      // doesn't move currentRouterUri, so assert on the rendered marker.
      expect(find.text('route:band-setlists'), findsOneWidget);
      expect(find.text('uri:/main/bands/band-123/setlists'), findsOneWidget);
    });

    testWidgets('shows a compact band header and "Band library" heading, not a '
        'personal greeting or personal tools (P1-4)', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final band = MockDataHelper.createMockBand(
        id: 'band-123',
        name: 'Teplo',
        members: [BandMember(uid: 'test-user-id', role: BandMember.roleAdmin)],
      );
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123',
        routes: [
          GoRoute(
            path: '/main/bands/:id',
            name: 'the-band',
            builder: (context, state) => TheBandScreen(band: band),
          ),
          GoRoute(
            path: '/main/bands/:id/rehearsals',
            name: 'band-rehearsals',
            builder: (context, state) =>
                const TestRouteMarker('band-rehearsals'),
          ),
        ],
        overrides: [
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

      // No personal-style greeting copy for the band.
      expect(find.text('Hello, Teplo!'), findsNothing);
      expect(find.textContaining('Ready to rock'), findsNothing);

      // Band name and member count still shown, in the compact header.
      expect(find.text('Teplo'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);

      // Statistics section is labeled for the band, not "My Library".
      expect(find.text('Band library'), findsOneWidget);
      expect(find.text('My Library'), findsNothing);

      // Personal tools are gone; Rehearsals is reachable as a quick action.
      expect(find.text('Tuner'), findsNothing);
      expect(find.text('Metronome'), findsNothing);
      expect(find.text('Rehearsals'), findsOneWidget);

      await tester.tap(find.text('Rehearsals'));
      await tester.pumpAndSettle();

      expect(find.text('route:band-rehearsals'), findsOneWidget);
    });
  });
}
