@Tags(['firebase-emulator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/screens/auth/forgot_password_screen.dart';

import '../helpers/firebase_emulator_harness.dart';
import '../helpers/routed_test_harness.dart';

class _AuthStatusText extends ConsumerWidget {
  const _AuthStatusText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: currentUser.when(
            data: (user) => Text(user?.email ?? 'signed-out'),
            loading: () => const Text('loading'),
            error: (error, _) => Text('error:$error'),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Authentication Flow Integration Tests - INT-AUTH-01', () {
    late FirebaseEmulatorHarness harness;

    setUp(() async {
      harness = await FirebaseEmulatorHarness.bootstrap();
      await harness.signOut();
    });

    testWidgets('creates a user through the register screen and routes home', (
      WidgetTester tester,
    ) async {
      final email = harness.uniqueEmail(prefix: 'register');
      const password = 'Password123!';

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: harness.providerOverrides(),
      );

      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      await tester.enterText(find.byType(TextFormField).at(2), password);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      final user = harness.auth.currentUser;
      addTearDown(() async {
        if (user != null) {
          await harness.clearUserData(user.uid);
        }
      });

      expect(user, isNotNull);
      expect(user?.email, email);
      expect(currentRouterUri(router).path, '/main/home');
    });

    testWidgets('signs in through the login screen and logs analytics', (
      WidgetTester tester,
    ) async {
      final email = harness.uniqueEmail(prefix: 'login');
      const password = 'Password123!';
      final credential = await harness.createAndSeedUser(
        email: email,
        password: password,
      );
      await harness.signOut();
      addTearDown(() async {
        await harness.clearUserData(credential.user!.uid);
      });

      final analytics = FakeAnalyticsClient();
      final pendingJoinCodeStore = FakePendingJoinCodeStore();

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: [
          ...harness.providerOverrides(),
          analyticsClientProvider.overrideWithValue(analytics),
          pendingJoinCodeStoreProvider.overrideWithValue(pendingJoinCodeStore),
        ],
      );

      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(harness.auth.currentUser?.email, email);
      expect(currentRouterUri(router).path, '/main/home');
      expect(analytics.loginMethods, ['email']);
      expect(analytics.loginSuccessMethods, ['email']);
    });

    testWidgets('surfaces mapped invalid-credential errors on login', (
      WidgetTester tester,
    ) async {
      final email = harness.uniqueEmail(prefix: 'invalid-login');
      const password = 'Password123!';
      final credential = await harness.createAndSeedUser(
        email: email,
        password: password,
      );
      await harness.signOut();
      addTearDown(() async {
        await harness.clearUserData(credential.user!.uid);
      });

      final analytics = FakeAnalyticsClient();
      final pendingJoinCodeStore = FakePendingJoinCodeStore();

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/login',
        overrides: [
          ...harness.providerOverrides(),
          analyticsClientProvider.overrideWithValue(analytics),
          pendingJoinCodeStoreProvider.overrideWithValue(pendingJoinCodeStore),
        ],
      );

      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), 'WrongPassword!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
      expect(harness.auth.currentUser, isNull);
    });

    testWidgets('accepts password reset requests through the forgot-password screen', (
      WidgetTester tester,
    ) async {
      final email = harness.uniqueEmail(prefix: 'reset');
      final credential = await harness.createAndSeedUser(email: email);
      await harness.signOut();
      addTearDown(() async {
        await harness.clearUserData(credential.user!.uid);
      });

      final container = ProviderContainer(
        overrides: harness.providerOverrides().cast(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ForgotPasswordScreen(initialEmail: email),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Email'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Password reset email sent!'), findsOneWidget);
    });

    testWidgets('preserves auth state across rebuilds and signs out cleanly', (
      WidgetTester tester,
    ) async {
      final email = harness.uniqueEmail(prefix: 'session');
      final credential = await harness.createAndSeedUser(email: email);
      addTearDown(() async {
        await harness.clearUserData(credential.user!.uid);
      });

      final container = ProviderContainer(
        overrides: harness.providerOverrides().cast(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _AuthStatusText(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(email), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _AuthStatusText(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(email), findsOneWidget);

      await container.read(appUserProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(find.text('signed-out'), findsOneWidget);
      expect(harness.auth.currentUser, isNull);
    });
  });
}
