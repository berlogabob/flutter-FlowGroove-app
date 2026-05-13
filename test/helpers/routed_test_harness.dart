import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/auth/register_screen.dart';
import 'package:flowgroove/screens/bands/my_bands_screen.dart';
import 'package:flowgroove/screens/login_screen.dart';
import 'package:flowgroove/screens/setlists/setlists_list_screen.dart';
import 'package:flowgroove/screens/songs/songs_list_screen.dart';

class TestAuthRouterClient implements AuthRouterClient {
  TestAuthRouterClient({this.user});

  final User? user;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(user);
}

class FakeAnalyticsClient extends AnalyticsClient {
  final List<String> loginMethods = <String>[];
  final List<String> loginSuccessMethods = <String>[];
  int demoLoginCount = 0;

  @override
  Future<void> logLogin({required String loginMethod}) async {
    loginMethods.add(loginMethod);
  }

  @override
  Future<void> logLoginSuccess({required String loginMethod}) async {
    loginSuccessMethods.add(loginMethod);
  }

  @override
  Future<void> logDemoLogin() async {
    demoLoginCount += 1;
  }

  @override
  Future<void> setUserProperties({
    required AppUser user,
    required int bandCount,
    required int songCount,
    required int setlistCount,
  }) async {}
}

class FakePendingJoinCodeStore extends PendingJoinCodeStore {
  FakePendingJoinCodeStore([this.pendingCode]);

  String? pendingCode;
  int readCount = 0;

  @override
  Future<String?> getAndClearPendingJoinCode() async {
    readCount += 1;
    final code = pendingCode;
    pendingCode = null;
    return code;
  }
}

class TestAppUserNotifier extends AppUserNotifier {
  TestAppUserNotifier(this.mockUser);

  final AppUser? mockUser;

  @override
  AsyncValue<AppUser?> build() => AsyncValue<AppUser?>.data(mockUser);
}

class TestRouteMarker extends StatelessWidget {
  const TestRouteMarker(this.routeName, {super.key});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('route:$routeName'), Text('uri:$uri')],
        ),
      ),
    );
  }
}

GoRouter createRoutedTestRouter({
  String initialLocation = '/login',
  List<RouteBase>? routes,
}) {
  return createAppRouter(
    authClient: TestAuthRouterClient(),
    initialLocation: initialLocation,
    navigatorKey: GlobalKey<NavigatorState>(),
    enableAuthRedirect: false,
    routes: routes ??
        [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/main/home',
        name: 'home',
        builder: (context, state) => const TestRouteMarker('home'),
      ),
      GoRoute(
        path: '/main/join-band',
        name: 'join-band',
        builder: (context, state) => const TestRouteMarker('join-band'),
      ),
      GoRoute(
        path: '/main/songs',
        name: 'songs',
        builder: (context, state) => const SongsListScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'add-song',
            builder: (context, state) => const TestRouteMarker('add-song'),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'edit-song',
            builder: (context, state) => const TestRouteMarker('edit-song'),
          ),
        ],
      ),
      GoRoute(
        path: '/main/bands',
        name: 'bands',
        builder: (context, state) => const MyBandsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            name: 'create-band',
            builder: (context, state) => const TestRouteMarker('create-band'),
          ),
          GoRoute(
            path: ':id',
            name: 'the-band',
            builder: (context, state) => const TestRouteMarker('the-band'),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'edit-band',
            builder: (context, state) => const TestRouteMarker('edit-band'),
          ),
          GoRoute(
            path: ':id/songs',
            name: 'band-songs',
            builder: (context, state) => const TestRouteMarker('band-songs'),
          ),
        ],
      ),
      GoRoute(
        path: '/main/setlists',
        name: 'setlists',
        builder: (context, state) => const SetlistsListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            name: 'create-setlist',
            builder: (context, state) =>
                const TestRouteMarker('create-setlist'),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'edit-setlist',
            builder: (context, state) => const TestRouteMarker('edit-setlist'),
          ),
        ],
      ),
    ],
  );
}

Future<GoRouter> pumpRoutedTestApp(
  WidgetTester tester, {
  required String initialLocation,
  List<dynamic> overrides = const [],
  List<RouteBase>? routes,
}) async {
  final container = ProviderContainer(overrides: overrides.cast());
  final router = createRoutedTestRouter(
    initialLocation: initialLocation,
    routes: routes,
  );

  addTearDown(container.dispose);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();

  return router;
}

Uri currentRouterUri(GoRouter router) {
  return router.routeInformationProvider.value.uri;
}
