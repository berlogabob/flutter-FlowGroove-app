import 'dart:async';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.dart';
import '../helpers/routed_test_harness.dart';

/// The band "add" flows (Add Song / Create Setlist) target routes that live in
/// *other* shell branches. They must be pushed, not go'd: a `go` switches the
/// shell branch, so saving drops the user on the personal library instead of
/// the band they started from.
///
/// This runs against the harness's production-shaped StatefulShellRoute + the
/// real MainShell, so it covers the cross-branch push behaviour that a flat
/// test router cannot show.
void main() {
  group('band add flows (cross-branch push)', () {
    for (final flow in const [
      ('/main/bands/band-1/songs', 'band-songs', 'add-song'),
      ('/main/bands/band-1/setlists', 'band-setlists', 'create-setlist'),
    ]) {
      final (from, fromMarker, target) = flow;

      testWidgets('$target pushed from $fromMarker returns on back', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = await pumpRoutedTestApp(
          tester,
          initialLocation: from,
          // The shell's branch roots are the real list screens; without these
          // they hit the live repositories and riverpod's retry timers trip
          // the pending-timer invariant at teardown.
          overrides: [
            appUserProvider.overrideWith(
              () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
            ),
            bandsProvider.overrideWith((ref) => Stream<List<Band>>.value([])),
            songsProvider.overrideWith((ref) => Stream<List<Song>>.value([])),
            setlistsProvider.overrideWith(
              (ref) => Stream<List<Setlist>>.value([]),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text('route:$fromMarker'), findsOneWidget);

        unawaited(
          router.pushNamed(target, queryParameters: {'bandId': 'band-1'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('route:$target'), findsOneWidget);

        // What _saveSong / _saveSetlist do when they finish.
        router.pop();
        await tester.pumpAndSettle();

        expect(find.text('route:$fromMarker'), findsOneWidget);
        expect(find.text('route:$target'), findsNothing);
      });
    }
  });
}
