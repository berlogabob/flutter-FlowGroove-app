import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:flowgroove/providers/auth/auth_provider.dart';

import '../helpers/routed_test_harness.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mocks.mocks.dart';

void main() {
  group('RegisterScreen', () {
    late MockFirebaseAuth mockAuth;

    List<dynamic> overrides() => [
      firebaseAuthProvider.overrideWithValue(mockAuth),
    ];

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    testWidgets('renders register screen with all elements', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Join FlowGroove'), findsOneWidget);
      expect(
        find.text('Create an account to manage your band repertoire'),
        findsOneWidget,
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Create Account'),
        findsOneWidget,
      );
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('displays input icons and password requirement', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsNWidgets(2));
      expect(find.text('At least 6 characters'), findsOneWidget);
    });

    testWidgets('allows entering email, password, and confirm password', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty submit', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows validation error for weak password', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), '12345');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error for mismatched passwords', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows loading indicator when registering', (tester) async {
      final completer = Completer<UserCredential>();
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) => completer.future);

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(createMockUserCredential());
      await tester.pumpAndSettle();
    });

    testWidgets('successful registration navigates home', (tester) async {
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => createMockUserCredential());

      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/home');
    });

    testWidgets('navigates to login screen when tapping Sign In', (
      tester,
    ) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/login');
      expect(find.text('FlowGroove'), findsOneWidget);
    });

    testWidgets('displays Firebase registration errors', (tester) async {
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/register',
        overrides: overrides(),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('This email is already registered'), findsOneWidget);
    });
  });
}
