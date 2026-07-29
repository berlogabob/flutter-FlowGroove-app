import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockUser extends Mock implements User {}

/// Simulates Firebase Auth during a cold start: [currentUser] is null until the
/// persisted session is restored, at which point [authStateChanges] emits the
/// user. This is the exact timing that orphaned the join deep link.
class _RaceAuthClient implements AuthRouterClient {
  _RaceAuthClient(this._controller);

  final StreamController<User?> _controller;
  User? user;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => _controller.stream;
}

List<RouteBase> _routes() {
  Widget marker(String name) =>
      Scaffold(body: Center(child: Text('route:$name')));
  return [
    GoRoute(path: '/login', name: 'login', builder: (c, s) => marker('login')),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (c, s) => marker('register'),
    ),
    GoRoute(
      path: '/join',
      name: 'join-deeplink',
      builder: (c, s) => marker('join-deeplink'),
    ),
    GoRoute(
      path: '/join-welcome',
      name: 'join-welcome',
      builder: (c, s) => marker('join-welcome'),
    ),
    GoRoute(path: '/main/home', name: 'home', builder: (c, s) => marker('home')),
    GoRoute(
      path: '/main/join-band',
      name: 'join-band',
      builder: (c, s) => marker('join-band'),
    ),
    GoRoute(
      path: '/main/bands',
      name: 'bands',
      builder: (c, s) => marker('bands'),
    ),
  ];
}

User _userWithEmail(String? email) {
  final user = _MockUser();
  when(() => user.email).thenReturn(email);
  return user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The logged-out branch stashes the code in flutter_secure_storage; stub the
  // channel so it's a harmless no-op in the test environment.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  testWidgets(
    'join deep link reaches join-band for an already-authenticated real user '
    'whose session restores just after launch',
    (tester) async {
      final controller = StreamController<User?>.broadcast();
      addTearDown(controller.close);
      final auth = _RaceAuthClient(controller);

      final router = createAppRouter(
        authClient: auth,
        enableAuthRedirect: true,
        initialLocation: '/join?code=ABC123',
        navigatorKey: GlobalKey<NavigatorState>(),
        routes: _routes(),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(); // first redirect runs while auth is still unresolved

      // Firebase restores the persisted session a moment after cold start.
      auth.user = _userWithEmail('real@user.com');
      controller.add(auth.user);
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/main/join-band');
      expect(uri.queryParameters['code'], 'ABC123');
    },
  );

  testWidgets(
    'join deep link shows the invite Welcome screen for a logged-out visitor',
    (tester) async {
      final controller = StreamController<User?>.broadcast();
      addTearDown(controller.close);
      final auth = _RaceAuthClient(controller);

      final router = createAppRouter(
        authClient: auth,
        enableAuthRedirect: true,
        initialLocation: '/join?code=ABC123',
        navigatorKey: GlobalKey<NavigatorState>(),
        routes: _routes(),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(); // first redirect runs while auth is still unresolved

      // Auth resolves to signed-out.
      controller.add(null);
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/join-welcome');
      expect(uri.queryParameters['code'], 'ABC123');
      expect(uri.path, isNot('/main/join-band'));
    },
  );

  testWidgets(
    'join deep link shows the invite Welcome screen for a demo-authed visitor',
    (tester) async {
      final controller = StreamController<User?>.broadcast();
      addTearDown(controller.close);
      final auth = _RaceAuthClient(controller);

      final router = createAppRouter(
        authClient: auth,
        enableAuthRedirect: true,
        initialLocation: '/join?code=ABC123',
        navigatorKey: GlobalKey<NavigatorState>(),
        routes: _routes(),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(); // first redirect runs while auth is still unresolved

      // The shared demo account restores just after cold start.
      auth.user = _userWithEmail('demo@flowgroove.app');
      controller.add(auth.user);
      await tester.pumpAndSettle();

      final uri = router.routeInformationProvider.value.uri;
      expect(uri.path, '/join-welcome');
      expect(uri.queryParameters['code'], 'ABC123');
      expect(uri.path, isNot('/main/join-band'));
    },
  );
}
