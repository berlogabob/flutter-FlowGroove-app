import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';

import '../helpers/mocks.dart';
import '../helpers/mocks.mocks.dart';
import '../helpers/routed_test_harness.dart';

class _HomeTestAppUserNotifier extends AppUserNotifier {
  _HomeTestAppUserNotifier(this.mockUser);

  final AppUser? mockUser;

  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(mockUser);
}

void main() {
  group('Home quick actions', () {
    late MockFirebaseAuth mockAuth;

    List<RouteBase> buildRoutes() {
      return [
        GoRoute(
          path: '/main/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/main/songs/add',
          name: 'add-song',
          builder: (context, state) => const AddSongScreen(),
        ),
        GoRoute(
          path: '/main/bands/create',
          name: 'create-band',
          builder: (context, state) => const TestRouteMarker('create-band'),
        ),
        GoRoute(
          path: '/main/setlists/create',
          name: 'create-setlist',
          builder: (context, state) => const TestRouteMarker('create-setlist'),
        ),
        GoRoute(
          path: '/main/tuner',
          name: 'tuner',
          builder: (context, state) => const TestRouteMarker('tuner'),
        ),
        GoRoute(
          path: '/main/metronome',
          name: 'metronome',
          builder: (context, state) => const TestRouteMarker('metronome'),
        ),
        GoRoute(
          path: '/main/songs',
          name: 'songs',
          builder: (context, state) => const TestRouteMarker('songs'),
        ),
      ];
    }

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    testWidgets('shows the Song quick action on the home screen', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/home',
        routes: buildRoutes(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          appUserProvider.overrideWith(() => _HomeTestAppUserNotifier(mockUser)),
          songsProvider.overrideWith((ref) => Stream.value([])),
          bandsProvider.overrideWith((ref) => Stream.value([])),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songCountProvider.overrideWith((ref) => 0),
          bandCountProvider.overrideWith((ref) => 0),
          setlistCountProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Song'), findsOneWidget);
    });

    testWidgets('routes from Home to the Add Song entry screen', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/home',
        routes: buildRoutes(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          appUserProvider.overrideWith(() => _HomeTestAppUserNotifier(mockUser)),
          songsProvider.overrideWith((ref) => Stream.value([])),
          bandsProvider.overrideWith((ref) => Stream.value([])),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songCountProvider.overrideWith((ref) => 0),
          bandCountProvider.overrideWith((ref) => 0),
          setlistCountProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Song'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/songs/add');
      expect(find.text('Add Song'), findsOneWidget);
    });
  });
}
