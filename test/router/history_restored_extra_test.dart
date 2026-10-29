import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mocks.dart';
import '../helpers/routed_test_harness.dart';

/// Browser back/forward on web restores `state.extra` from `history.state` as
/// decoded JSON (a Map), not the original model object — go_router has no
/// extraCodec here. The PRODUCTION route builders must treat a wrong-typed
/// extra as absent and reload by id, instead of crashing on a cast
/// ("Something went wrong" screen). Regression test for the iPhone Safari /
/// all-browsers back-button crash.
void main() {
  final band = Band(
    id: 'b1',
    name: 'Live Band',
    createdBy: 'u1',
    createdAt: DateTime(2024),
  );
  final setlist = Setlist(
    id: 's1',
    bandId: '',
    name: 'Live Setlist',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  Future<GoRouter> pumpProductionRouter(
    WidgetTester tester, {
    required String initialLocation,
  }) async {
    // No navigatorKey override: the production tool routes hardcode
    // parentNavigatorKey to the module's root key.
    final router = createAppRouter(
      authClient: TestAuthRouterClient(),
      initialLocation: initialLocation,
      enableAuthRedirect: false,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUserProvider.overrideWith(
            () => TestAppUserNotifier(MockDataHelper.createMockAppUser()),
          ),
          bandsProvider.overrideWith((ref) => Stream.value([band])),
          songsProvider.overrideWith((ref) => Stream<List<Song>>.value([])),
          setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  testWidgets('the-band renders when extra is history-restored JSON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = await pumpProductionRouter(
      tester,
      initialLocation: '/main/home',
    );

    // Simulate a browser-restored history entry: extra is the JSON map, not
    // a Band. Before the fix this threw TypeError in the route builder.
    router.go('/main/bands/b1', extra: band.toJson());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Resolver fell back to the live stream by id.
    expect(find.text('Live Band'), findsWidgets);
  });

  testWidgets('setlist-view renders when extra is history-restored JSON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = await pumpProductionRouter(
      tester,
      initialLocation: '/main/home',
    );

    router.go('/main/setlists/s1', extra: setlist.toJson());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Live Setlist'), findsWidgets);
  });
}
