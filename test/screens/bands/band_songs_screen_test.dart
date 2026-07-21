import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/bands/band_songs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/routed_test_harness.dart';

void main() {
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
  });
}
