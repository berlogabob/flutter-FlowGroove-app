import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/tuner_launch_context.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/bands/band_songs_screen.dart';
import 'package:flowgroove/screens/songs/songs_list_screen.dart';
import 'package:flowgroove/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/routed_test_harness.dart';
import '../../providers/data_providers_test.mocks.dart' as repositories;

class _LiveUser extends TestAppUserNotifier {
  _LiveUser(super.user);

  void update(AsyncValue<AppUser?> value) => state = value;
}

void main() {
  for (final bandScope in [false, true]) {
    testWidgets(
      'tuner callback keeps ${bandScope ? 'band' : 'personal'} target and rejects stale authority',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final user = MockDataHelper.createMockAppUser();
        final liveUser = _LiveUser(user);
        final firebaseUser = MockUser();
        when(firebaseUser.uid).thenReturn(user.uid);
        final band = MockDataHelper.createMockBand(
          id: 'band-123',
          members: [BandMember(uid: user.uid, role: BandMember.roleEditor)],
        );
        // Stale/missing metadata must not override the actual library scope.
        final song = MockDataHelper.createMockSong(
          id: 'song-1',
          title: 'Tuner Song',
          bandId: 'old-band',
        );
        final updated = song.copyWith(
          defaultTuningPresetId: 'builtin:guitar-standard',
        );
        final repo = repositories.MockSongRepository();
        when(repo.saveSong(any, uid: anyNamed('uid'))).thenAnswer((_) async {});
        when(repo.updateBandSong(any, any)).thenAnswer((_) async {});
        final bands = StreamController<List<Band>>();
        addTearDown(bands.close);
        AsyncValue<User?> auth = AsyncData(firebaseUser);
        final container = ProviderContainer(
          overrides: [
            appUserProvider.overrideWith(() => liveUser),
            currentUserProvider.overrideWith((ref) => auth),
            bandsProvider.overrideWith((ref) => bands.stream),
            songsProvider.overrideWith((ref) => Stream.value([song])),
            bandSongsProvider.overrideWith((ref, id) => Stream.value([song])),
            songRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);
        TunerLaunchContext? launch;
        final router = createRoutedTestRouter(
          initialLocation: '/library',
          routes: [
            GoRoute(
              path: '/library',
              builder: (_, _) => bandScope
                  ? BandSongsScreen(band: band)
                  : const SongsListScreen(),
            ),
            GoRoute(
              path: '/tuner',
              name: 'tuner',
              builder: (_, state) {
                launch = state.extra! as TunerLaunchContext;
                return const TestRouteMarker('tuner');
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        bands.add([band]);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open in Tuner'));
        await tester.pumpAndSettle();
        expect(launch, isNotNull);
        expect(launch!.bandId, bandScope ? 'band-123' : null);
        expect(launch!.effectiveBandId, bandScope ? 'band-123' : null);
        final save = launch!.saveSong!;
        await save(updated);
        if (bandScope) {
          verify(repo.updateBandSong(updated, 'band-123')).called(1);
          verifyNever(repo.saveSong(any, uid: anyNamed('uid')));
        } else {
          verify(repo.saveSong(updated, uid: user.uid)).called(1);
          verifyNever(repo.updateBandSong(any, any));
        }
        clearInteractions(repo);
        await expectLater(
          save(updated.copyWith(id: 'other-song')),
          throwsStateError,
        );
        liveUser.update(
          AsyncData(MockDataHelper.createMockAppUser(uid: 'other-user')),
        );
        await expectLater(save(updated), throwsStateError);
        liveUser.update(const AsyncLoading());
        await expectLater(save(updated), throwsStateError);
        liveUser.update(AsyncError(StateError('offline'), StackTrace.current));
        await expectLater(save(updated), throwsStateError);
        liveUser.update(AsyncData(user.copyWith(accessRole: 'demo')));
        await expectLater(save(updated), throwsStateError);
        liveUser.update(AsyncData(user));
        final otherUser = MockUser();
        when(otherUser.uid).thenReturn('other-user');
        for (final value in <AsyncValue<User?>>[
          const AsyncData(null),
          AsyncData(otherUser),
          const AsyncLoading(),
          AsyncError(StateError('offline'), StackTrace.current),
        ]) {
          auth = value;
          container.invalidate(currentUserProvider);
          await expectLater(save(updated), throwsStateError);
        }
        auth = AsyncData(firebaseUser);
        container.invalidate(currentUserProvider);
        if (bandScope) {
          bands.add([]);
          await tester.pumpAndSettle();
          expect(container.read(bandsProvider).asData?.value, isEmpty);
          await expectLater(save(updated), throwsStateError);
          bands.addError(StateError('offline'));
          await tester.pump();
          await expectLater(save(updated), throwsStateError);
        }
        verifyNever(repo.saveSong(any, uid: anyNamed('uid')));
        verifyNever(repo.updateBandSong(any, any));
        bands.add([band]);
        liveUser.update(AsyncData(user.copyWith(accessRole: 'demo')));
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open in Tuner'));
        await tester.pumpAndSettle();
        expect(launch!.saveSong, isNull);
        liveUser.update(AsyncData(user));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await expectLater(save(updated), throwsStateError);
      },
    );
  }
  group('BandSongsScreen', () {
    testWidgets('Add Song opens the song form scoped to the band, and Back '
        'returns to the band', (tester) async {
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
        initialLocation: '/main/bands/band-123/songs',
        routes: [
          GoRoute(
            path: '/main/bands/:id/songs',
            name: 'band-songs',
            builder: (context, state) => BandSongsScreen(band: band),
          ),
          GoRoute(
            path: '/main/songs/add',
            name: 'add-song',
            builder: (context, state) => TestRouteMarker(
              'add-song:${state.uri.queryParameters['bandId']}',
            ),
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
        ],
      );
      await tester.pumpAndSettle();

      // Empty state action (the FAB routes through the same handler).
      await tester.tap(find.text('Add Song'));
      await tester.pumpAndSettle();

      // The form opened, carrying the band id so the save targets the band.
      expect(find.text('route:add-song:band-123'), findsOneWidget);

      // Pushed, not go'd: popping (what _saveSong does) lands back on the
      // band's songs, not on the personal library.
      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('No songs yet'), findsOneWidget);
      expect(find.textContaining('route:add-song'), findsNothing);
    });

    // Shared scaffolding for the permission-matrix tests below.
    Future<GoRouter> pumpWithBand(
      WidgetTester tester,
      Band band, {
      List<Song>? songs,
      FirestoreService? firestore,
    }) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('test-user-id');

      return pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands/band-123/songs',
        routes: [
          GoRoute(
            path: '/main/bands/:id/songs',
            name: 'band-songs',
            builder: (context, state) => BandSongsScreen(band: band),
          ),
          GoRoute(
            path: '/main/songs/add',
            name: 'add-song',
            builder: (context, state) => const TestRouteMarker('add-song'),
          ),
          GoRoute(
            path: '/main/songs/:id',
            name: 'song',
            builder: (context, state) =>
                TestRouteMarker('song:${state.uri.queryParameters['bandId']}'),
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
          if (firestore != null) firestoreProvider.overrideWithValue(firestore),
          bandSongsProvider.overrideWith(
            (ref, bandId) => Stream<List<Song>>.value(
              songs ??
                  [
                    MockDataHelper.createMockSong(
                      id: 'song-1',
                      title: 'Band Song',
                      bandId: 'band-123',
                    ),
                  ],
            ),
          ),
        ],
      );
    }

    testWidgets(
      'editor via arrays edits even when members[].role is stale (regression)',
      (tester) async {
        // The reported bug: uid in editorUids (what rules read) but the
        // members[] entry says viewer — the old members[].role gate hid every
        // edit affordance from a legitimate editor.
        final band = Band(
          id: 'band-123',
          name: 'Band 123',
          createdBy: 'owner',
          createdAt: DateTime(2024),
          members: [
            BandMember(uid: 'test-user-id', role: BandMember.roleViewer),
          ],
          memberUids: const ['test-user-id'],
          adminUids: const [],
          editorUids: const ['test-user-id'],
        );

        await pumpWithBand(tester, band);
        await tester.pumpAndSettle();

        // Editor affordances present…
        expect(find.byType(FloatingActionButton), findsOneWidget);

        // …and the card tap opens the Song Page carrying ?bandId=.
        await tester.tap(find.text('Band Song'));
        await tester.pumpAndSettle();
        expect(find.text('route:song:band-123'), findsOneWidget);
      },
    );

    testWidgets('viewer card tap still opens the Song Page (no dead card)', (
      tester,
    ) async {
      final band = MockDataHelper.createMockBand(
        id: 'band-123',
        name: 'Band 123',
        members: [BandMember(uid: 'test-user-id', role: BandMember.roleViewer)],
      );

      await pumpWithBand(tester, band);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('Band Song'));
      await tester.pumpAndSettle();
      expect(find.text('route:song:band-123'), findsOneWidget);
    });

    testWidgets('delete is admin-only: editor swipe does not delete', (
      tester,
    ) async {
      final firestore = MockFirestoreService();
      when(firestore.deleteBandSong(any, any)).thenAnswer((_) async {});

      final band = MockDataHelper.createMockBand(
        id: 'band-123',
        name: 'Band 123',
        members: [BandMember(uid: 'test-user-id', role: BandMember.roleEditor)],
      );

      await pumpWithBand(tester, band, firestore: firestore);
      await tester.pumpAndSettle();

      await tester.drag(find.text('Band Song'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      verifyNever(firestore.deleteBandSong(any, any));
      expect(find.text('Band Song'), findsOneWidget);
    });
  });
}
