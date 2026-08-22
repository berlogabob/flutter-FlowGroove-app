import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockUser extends Mock implements User {}

class _AuthClient implements AuthRouterClient {
  _AuthClient(this._controller);

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
      path: '/join-welcome',
      name: 'join-welcome',
      builder: (c, s) => marker('join-welcome'),
    ),
    GoRoute(
      path: '/event',
      name: 'event-share',
      builder: (c, s) => marker('event:${s.uri.queryParameters['t']}'),
    ),
    GoRoute(path: '/main/home', name: 'home', builder: (c, s) => marker('home')),
  ];
}

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    User? user,
  }) async {
    final controller = StreamController<User?>.broadcast();
    addTearDown(controller.close);
    final auth = _AuthClient(controller)..user = user;
    final router = createAppRouter(
      authClient: auth,
      initialLocation: location,
      navigatorKey: GlobalKey<NavigatorState>(),
      routes: _routes(),
      observers: const [],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  group('shared event link', () {
    testWidgets('opens for a signed-OUT visitor instead of bouncing to login', (
      tester,
    ) async {
      // The whole point: a venue's art director or a wedding couple must be
      // able to read the event and suggest changes without an account. The
      // token is the grant; the server scopes the payload to it.
      await pumpAt(tester, '/event?t=tok123.secret');
      expect(find.text('route:event:tok123.secret'), findsOneWidget);
      expect(find.text('route:login'), findsNothing);
    });

    testWidgets('also opens for a signed-in user', (tester) async {
      await pumpAt(tester, '/event?t=tok123.secret', user: _MockUser());
      expect(find.text('route:event:tok123.secret'), findsOneWidget);
    });

    testWidgets('a signed-out visitor is still bounced off app routes', (
      tester,
    ) async {
      // Guard against the /event exemption widening: everything else must keep
      // requiring auth.
      await pumpAt(tester, '/main/home');
      expect(find.text('route:login'), findsOneWidget);
    });
  });
}
