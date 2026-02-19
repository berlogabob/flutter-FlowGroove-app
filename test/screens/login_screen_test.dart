import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_repsync_app/screens/login_screen.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mocks.dart';

void main() {
  group('LoginScreen', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
    });

    testWidgets('renders login screen with all elements', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Verify screen title
      expect(findText('Welcome Back'), findsOneWidget);

      // Verify app name
      expect(findText('RepSync'), findsOneWidget);

      // Verify subtitle
      expect(findText('Sign in to manage your band'), findsOneWidget);

      // Verify email field
      expect(findText('Email'), findsOneWidget);

      // Verify password field
      expect(findText('Password'), findsOneWidget);

      // Verify sign in button
      expect(findText('Sign In'), findsOneWidget);

      // Verify sign up link
      expect(findText("Don't have an account?"), findsOneWidget);
      expect(findText('Sign Up'), findsOneWidget);
    });

    testWidgets('displays email icon and password icon', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      expect(findIcon(Icons.email_outlined), findsOneWidget);
      expect(findIcon(Icons.lock_outlined), findsOneWidget);
    });

    testWidgets('allows entering email and password', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Find text fields
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      // Enter email
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      // Enter password
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Verify text was entered
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows validation error for empty email', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Tap sign in button without entering data
      await tester.tap(findText('Sign In'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('shows validation error for empty password', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Enter email only
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      // Tap sign in button
      await tester.tap(findText('Sign In'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows loading indicator when logging in', (
      WidgetTester tester,
    ) async {
      // Setup mock to simulate async login
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => createMockUserCredential());

      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Enter credentials
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Tap sign in button
      await tester.tap(findText('Sign In'));
      await tester.pump();

      // Verify loading indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('navigates to register screen when tapping Sign Up', (
      WidgetTester tester,
    ) async {
      bool didNavigate = false;

      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (_) => didNavigate = true),
        ],
      );

      // Tap Sign Up button
      await tester.tap(findText('Sign Up'));
      await tester.pump();

      // Verify navigation occurred
      expect(didNavigate, isTrue);
    });

    testWidgets('displays error message for invalid credentials', (
      WidgetTester tester,
    ) async {
      // Setup mock to throw auth error
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Enter credentials
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Tap sign in button
      await tester.tap(findText('Sign In'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.text('No user found with this email'), findsOneWidget);
    });

    testWidgets('displays error message for wrong password', (
      WidgetTester tester,
    ) async {
      // Setup mock to throw auth error
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Enter credentials
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Tap sign in button
      await tester.tap(findText('Sign In'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.text('Wrong password'), findsOneWidget);
    });

    testWidgets('displays error message for invalid email', (
      WidgetTester tester,
    ) async {
      // Setup mock to throw auth error
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-email'));

      await pumpAppWidget(
        tester,
        const LoginScreen(),
        overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
      );

      // Enter credentials
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Tap sign in button
      await tester.tap(findText('Sign In'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.text('Invalid email address'), findsOneWidget);
    });
  });
}

/// Mock navigator observer for testing navigation
class MockNavigatorObserver extends NavigatorObserver {
  final Function(Route<dynamic>)? onPush;
  final Function(Route<dynamic>)? onPop;

  MockNavigatorObserver({this.onPush, this.onPop});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPush?.call(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPop?.call(route);
  }
}
