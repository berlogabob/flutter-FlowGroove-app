import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/routed_test_harness.dart';
import '../screens/songs/songs_list_screen_test.dart' show createTestUser;

void main() {
  testWidgets('production routes show the home screen', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpRoutedTestApp(
      tester,
      initialLocation: '/main/home',
      productionRoutes: true,
      overrides: [
        appUserProvider.overrideWith(() => TestAppUserNotifier(createTestUser())),
        songsProvider.overrideWith((ref) => Stream.value([])),
        bandsProvider.overrideWith((ref) => Stream.value([])),
        setlistsProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TestRouteMarker), findsNothing);
  });

  testWidgets('theme mode, text scale and boundary', (tester) async {
    const key = Key('boundary');
    await pumpRoutedTestApp(
      tester,
      initialLocation: '/login',
      themeMode: ThemeMode.dark,
      textScale: 1.3,
      boundaryKey: key,
    );
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(MediaQuery.textScalerOf(context).scale(10), greaterThanOrEqualTo(13));
    expect(find.byKey(key), findsOneWidget);
    expect(tester.widget(find.byKey(key)), isA<RepaintBoundary>());
  });
}
