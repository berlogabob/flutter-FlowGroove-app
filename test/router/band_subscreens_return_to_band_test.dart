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

/// Opening a band's Songs / Setlists from the band-detail screen must PUSH, not
/// go: those routes are flat siblings of `the-band` under `/main/bands`, so a
/// `go` rebuilds the stack as [bands, band-songs] and Back drops the user on the
/// all-bands list instead of the band they came from. Pushing keeps `the-band`
/// underneath so Back returns to it. Runs against the production-shaped
/// StatefulShellRoute (same flat tree as app_router.dart).
void main() {
  group('band sub-screens return to band-detail on back', () {
    for (final target in const ['band-songs', 'band-setlists']) {
      testWidgets('$target pushed from the-band returns to the-band on back', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = await pumpRoutedTestApp(
          tester,
          initialLocation: '/main/bands/band-1',
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
        expect(find.text('route:the-band'), findsOneWidget);

        unawaited(
          router.pushNamed(target, pathParameters: {'id': 'band-1'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('route:$target'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();

        // Back must land on band-detail, not the all-bands list.
        expect(find.text('route:the-band'), findsOneWidget);
        expect(find.text('route:$target'), findsNothing);
        expect(find.text('route:bands'), findsNothing);
      });
    }
  });
}
