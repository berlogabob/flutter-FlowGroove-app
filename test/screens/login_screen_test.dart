import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/mocks.mocks.dart';
import '../helpers/routed_test_harness.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('LoginScreen', () {
    late MockFirebaseAuth mockAuth;
    late FakeAnalyticsClient analytics;
    late FakePendingJoinCodeStore pendingJoinCodeStore;

    List<dynamic> overrides() => [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      analyticsClientProvider.overrideWithValue(analytics),
      pendingJoinCodeStoreProvider.overrideWithValue(pendingJoinCodeStore),
      appUserProvider.overrideWith(() => TestAppUserNotifier(null)),
    ];

    setUp(() {
      mockAuth = MockFirebaseAuth();
      analytics = FakeAnalyticsClient();
      pendingJoinCodeStore = FakePendingJoinCodeStore();
    });

    testWidgets('renders login screen with all elements', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      expect(find.text('FlowGroove'), findsOneWidget);
      expect(find.text('Sign in to manage your band'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Try Demo Account'), findsOneWidget);
    });

    testWidgets('displays email and password icons', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
    });

    testWidgets('allows entering email and password', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty submit', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      verifyNever(
        mockAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      );
    });

    testWidgets('shows password validation after email entry', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows loading indicator while login is pending', (
      tester,
    ) async {
      final completer = Completer<UserCredential>();
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'Password123',
        ),
      ).thenAnswer((_) => completer.future);

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(createMockUserCredential());
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to register with GoRouter when tapping Sign Up', (
      tester,
    ) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/register');
      expect(find.text('Join FlowGroove'), findsOneWidget);
    });

    testWidgets('successful login logs analytics and navigates home', (
      tester,
    ) async {
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'Password123',
        ),
      ).thenAnswer((_) async => createMockUserCredential());

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/home');
      expect(analytics.loginMethods, ['email']);
      expect(analytics.loginSuccessMethods, ['email']);
      expect(pendingJoinCodeStore.readCount, 1);
    });

    testWidgets(
      'successful login with pending join code navigates to join band',
      (tester) async {
        pendingJoinCodeStore.pendingCode = 'ABC123';
        when(
          mockAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'Password123',
          ),
        ).thenAnswer((_) async => createMockUserCredential());

        final router = await pumpRoutedTestApp(
          tester,
          initialLocation: '/login',
          overrides: overrides(),
        );

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'test@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
        await tester.pumpAndSettle();

        expect(currentRouterUri(router).path, '/main/join-band');
        expect(currentRouterUri(router).queryParameters['code'], 'ABC123');
        expect(find.text('route:join-band'), findsOneWidget);
      },
    );

    testWidgets('demo login uses injected analytics and navigates home', (
      tester,
    ) async {
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'demo@flowgroove.app',
          password: 'demo1234',
        ),
      ).thenAnswer((_) async => createMockUserCredential());

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.tap(find.text('Try Demo Account'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/home');
      expect(analytics.demoLoginCount, 1);
    });

    testWidgets('displays auth error messages', (tester) async {
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'Password123',
        ),
      ).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: overrides(),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('Incorrect password. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
