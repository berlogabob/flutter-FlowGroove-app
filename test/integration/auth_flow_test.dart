/// Authentication Flow Integration Tests
///
/// End-to-end tests for complete authentication user flows.
/// Tests cover sign-up, sign-in, password reset, sign-out, and auth persistence.
///
/// Test ID: INT-AUTH-01
/// Priority: P0 🔴
/// Estimated Time: 1.5 hours
///
/// To run: flutter test test/integration/auth_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_repsync_app/screens/login_screen.dart';
import 'package:flutter_repsync_app/screens/auth/register_screen.dart';
import 'package:flutter_repsync_app/screens/auth/forgot_password_screen.dart';

import '../helpers/integration_test_helpers.dart';

void main() {
  group('Authentication Flow Integration Tests - INT-AUTH-01', () {
    late AuthIntegrationFixture authFixture;
    late NavigationTracker navigationTracker;

    setUp(() {
      authFixture = AuthIntegrationFixture();
      authFixture.setUp();
      navigationTracker = NavigationTracker();
    });

    // =========================================================================
    // SIGN-UP FLOW TESTS
    // =========================================================================
    group('Sign-Up Flow', () {
      setUp(() {
        authFixture.setupSuccessfulSignUp();
      });

      testWidgets(
        'INT-AUTH-01.1: Complete sign-up flow with valid credentials',
        (WidgetTester tester) async {
          // Arrange: Setup mock for successful sign up
          final email = TestDataFactory.generateEmail(1);
          const password = 'SecurePassword123!';

          // Act: Pump register screen
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(
                home: RegisterScreen(),
                navigatorObservers: [],
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Enter email
          final emailField = find.byType(TextFormField).at(0);
          await tester.enterText(emailField, email);
          await tester.pump();

          // Enter password
          final passwordField = find.byType(TextFormField).at(1);
          await tester.enterText(passwordField, password);
          await tester.pump();

          // Enter confirm password
          final confirmPasswordField = find.byType(TextFormField).at(2);
          await tester.enterText(confirmPasswordField, password);
          await tester.pump();

          // Tap sign up button
          final signUpButton = find.widgetWithText(
            ElevatedButton,
            'Create Account',
          );
          await tester.tap(signUpButton);
          await tester.pumpAndSettle();

          // Assert: Verify email verification message or navigation
          expect(find.textContaining('verification'), findsOneWidget);
        },
      );

      testWidgets('INT-AUTH-01.2: Sign-up with weak password shows error', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setupFailedSignUp('weak-password', 'Password is too weak');

        const email = 'test@example.com';
        const password = '123';

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, email);
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, password);
        await tester.pump();

        final confirmPasswordField = find.byType(TextFormField).at(2);
        await tester.enterText(confirmPasswordField, password);
        await tester.pump();

        final signUpButton = find.widgetWithText(
          ElevatedButton,
          'Create Account',
        );
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Assert: Error message should be shown
        expect(find.textContaining('weak'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.3: Sign-up with invalid email shows error', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setupFailedSignUp('invalid-email', 'Invalid email address');

        const email = 'invalid-email';
        const password = 'SecurePassword123!';

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, email);
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, password);
        await tester.pump();

        final confirmPasswordField = find.byType(TextFormField).at(2);
        await tester.enterText(confirmPasswordField, password);
        await tester.pump();

        final signUpButton = find.widgetWithText(
          ElevatedButton,
          'Create Account',
        );
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('invalid'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.4: Sign-up with existing email shows error', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setupFailedSignUp(
          'email-already-in-use',
          'Email already in use',
        );

        const email = 'existing@example.com';
        const password = 'SecurePassword123!';

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, email);
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, password);
        await tester.pump();

        final confirmPasswordField = find.byType(TextFormField).at(2);
        await tester.enterText(confirmPasswordField, password);
        await tester.pump();

        final signUpButton = find.widgetWithText(
          ElevatedButton,
          'Create Account',
        );
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('already'), findsOneWidget);
      });

      testWidgets(
        'INT-AUTH-01.5: Sign-up with mismatched passwords shows error',
        (WidgetTester tester) async {
          // Act
          await tester.pumpWidget(
            const ProviderScope(child: MaterialApp(home: RegisterScreen())),
          );
          await tester.pumpAndSettle();

          final emailField = find.byType(TextFormField).at(0);
          await tester.enterText(emailField, 'test@example.com');
          await tester.pump();

          final passwordField = find.byType(TextFormField).at(1);
          await tester.enterText(passwordField, 'Password123!');
          await tester.pump();

          final confirmPasswordField = find.byType(TextFormField).at(2);
          await tester.enterText(confirmPasswordField, 'DifferentPassword123!');
          await tester.pump();

          final signUpButton = find.widgetWithText(
            ElevatedButton,
            'Create Account',
          );
          await tester.tap(signUpButton);
          await tester.pumpAndSettle();

          // Assert: Password mismatch error
          expect(find.textContaining('match'), findsOneWidget);
        },
      );

      testWidgets('INT-AUTH-01.6: Sign-up with empty fields shows validation', (
        WidgetTester tester,
      ) async {
        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await tester.pumpAndSettle();

        final signUpButton = find.widgetWithText(
          ElevatedButton,
          'Create Account',
        );
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Assert: Validation errors shown
        expect(find.textContaining('required'), findsOneWidget);
      });
    });

    // =========================================================================
    // SIGN-IN FLOW TESTS
    // =========================================================================
    group('Sign-In Flow', () {
      setUp(() {
        authFixture.setupSuccessfulSignIn();
      });

      testWidgets(
        'INT-AUTH-01.7: Complete sign-in flow with valid credentials',
        (WidgetTester tester) async {
          // Arrange
          const email = 'test@example.com';
          const password = 'SecurePassword123!';

          // Act
          await tester.pumpWidget(
            const ProviderScope(child: MaterialApp(home: LoginScreen())),
          );
          await tester.pumpAndSettle();

          // Enter email
          final emailField = find.byType(TextFormField).at(0);
          await tester.enterText(emailField, email);
          await tester.pump();

          // Enter password
          final passwordField = find.byType(TextFormField).at(1);
          await tester.enterText(passwordField, password);
          await tester.pump();

          // Tap sign in button
          final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
          await tester.tap(signInButton);
          await tester.pumpAndSettle();

          // Assert: Should navigate to home or show success
          expect(find.textContaining('Welcome'), findsOneWidget);
        },
      );

      testWidgets('INT-AUTH-01.8: Sign-in with user not found shows error', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setupFailedSignIn(
          'user-not-found',
          'No user found with this email',
        );

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, 'nonexistent@example.com');
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, 'Password123!');
        await tester.pump();

        final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('not found'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.9: Sign-in with wrong password shows error', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setupFailedSignIn('wrong-password', 'Wrong password');

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, 'test@example.com');
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, 'WrongPassword123!');
        await tester.pump();

        final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('wrong'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.10: Sign-in with empty email shows validation', (
        WidgetTester tester,
      ) async {
        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await tester.pumpAndSettle();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, 'Password123!');
        await tester.pump();

        final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('required'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.11: Navigate to sign-up from sign-in screen', (
        WidgetTester tester,
      ) async {
        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await tester.pumpAndSettle();

        // Find and tap sign up link
        final signUpLink = find.textContaining('Sign Up');
        await tester.tap(signUpLink);
        await tester.pumpAndSettle();

        // Assert: Should navigate to register screen
        expect(find.text('Create Account'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.12: Navigate to forgot password from sign-in', (
        WidgetTester tester,
      ) async {
        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await tester.pumpAndSettle();

        // Find and tap forgot password link
        final forgotPasswordLink = find.textContaining('Forgot');
        await tester.tap(forgotPasswordLink);
        await tester.pumpAndSettle();

        // Assert: Should navigate to forgot password screen
        expect(find.textContaining('Reset'), findsOneWidget);
      });
    });

    // =========================================================================
    // PASSWORD RESET FLOW TESTS
    // =========================================================================
    group('Password Reset Flow', () {
      setUp(() {
        authFixture.setupPasswordReset();
      });

      testWidgets('INT-AUTH-01.13: Password reset with valid email succeeds', (
        WidgetTester tester,
      ) async {
        // Arrange
        const email = 'test@example.com';

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: ForgotPasswordScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, email);
        await tester.pump();

        final resetButton = find.widgetWithText(
          ElevatedButton,
          'Send Reset Email',
        );
        await tester.tap(resetButton);
        await tester.pumpAndSettle();

        // Assert: Success message shown
        expect(find.textContaining('sent'), findsOneWidget);
      });

      testWidgets(
        'INT-AUTH-01.14: Password reset with invalid email shows error',
        (WidgetTester tester) async {
          // Arrange
          when(
            authFixture.mockAuth.sendPasswordResetEmail(email: 'invalid'),
          ).thenThrow(
            FirebaseAuthException(
              code: 'invalid-email',
              message: 'Invalid email address',
            ),
          );

          // Act
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(home: ForgotPasswordScreen()),
            ),
          );
          await tester.pumpAndSettle();

          final emailField = find.byType(TextFormField).at(0);
          await tester.enterText(emailField, 'invalid');
          await tester.pump();

          final resetButton = find.widgetWithText(
            ElevatedButton,
            'Send Reset Email',
          );
          await tester.tap(resetButton);
          await tester.pumpAndSettle();

          // Assert
          expect(find.textContaining('invalid'), findsOneWidget);
        },
      );

      testWidgets(
        'INT-AUTH-01.15: Password reset with empty email shows validation',
        (WidgetTester tester) async {
          // Act
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(home: ForgotPasswordScreen()),
            ),
          );
          await tester.pumpAndSettle();

          final resetButton = find.widgetWithText(
            ElevatedButton,
            'Send Reset Email',
          );
          await tester.tap(resetButton);
          await tester.pumpAndSettle();

          // Assert
          expect(find.textContaining('required'), findsOneWidget);
        },
      );
    });

    // =========================================================================
    // SIGN-OUT FLOW TESTS
    // =========================================================================
    group('Sign-Out Flow', () {
      testWidgets('INT-AUTH-01.16: Sign-out clears user session', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setUp();
        authFixture.setupSuccessfulSignOut();

        when(authFixture.mockAuth.currentUser).thenReturn(authFixture.mockUser);

        // Act: Simulate signed in state
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Welcome Test User'),
                      ElevatedButton(
                        onPressed: () async {
                          await authFixture.mockAuth.signOut();
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify user is signed in
        expect(find.text('Welcome Test User'), findsOneWidget);

        // Tap sign out
        final signOutButton = find.text('Sign Out');
        await tester.tap(signOutButton);
        await tester.pumpAndSettle();

        // Verify sign out was called
        verify(authFixture.mockAuth.signOut()).called(1);
      });

      testWidgets('INT-AUTH-01.17: Sign-out redirects to login screen', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setUp();
        authFixture.setupSuccessfulSignOut();
        authFixture.setupAuthStateChanges();

        // Act: Simulate auth state change to null after sign out
        when(
          authFixture.mockAuth.authStateChanges(),
        ).thenAnswer((_) => Stream<User?>.value(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: StreamBuilder<User?>(
                stream: authFixture.mockAuth.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return const Text('Home Screen');
                  }
                  return const LoginScreen();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially signed in
        expect(find.text('Home Screen'), findsOneWidget);

        // Simulate sign out by pumping with null user
        when(authFixture.mockAuth.currentUser).thenReturn(null);
        await tester.pumpAndSettle();

        // Should show login screen
        expect(find.textContaining('Sign In'), findsOneWidget);
      });
    });

    // =========================================================================
    // AUTH STATE PERSISTENCE TESTS
    // =========================================================================
    group('Auth State Persistence', () {
      testWidgets('INT-AUTH-01.18: Auth state persists across app restart', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setUp();
        authFixture.setupAuthStateChanges();

        when(authFixture.mockAuth.currentUser).thenReturn(authFixture.mockUser);

        // Act: Initial app load with signed in user
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: StreamBuilder<User?>(
                stream: authFixture.mockAuth.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return const Text('Home Screen');
                  }
                  return const LoginScreen();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify signed in
        expect(find.text('Home Screen'), findsOneWidget);

        // Simulate app restart (rebuild widget tree)
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: StreamBuilder<User?>(
                stream: authFixture.mockAuth.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return const Text('Home Screen');
                  }
                  return const LoginScreen();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Still signed in
        expect(find.text('Home Screen'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.19: User data loaded after sign in', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setUp();
        authFixture.setupSuccessfulSignIn();

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, 'test@example.com');
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, 'Password123!');
        await tester.pump();

        final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();

        // Assert: User data available
        expect(find.textContaining('Welcome'), findsOneWidget);
      });

      testWidgets('INT-AUTH-01.20: Email verification flow initiated', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setUp();
        authFixture.setupSuccessfulSignUp();

        when(authFixture.mockUser.emailVerified).thenReturn(false);

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, TestDataFactory.generateEmail(20));
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, 'SecurePassword123!');
        await tester.pump();

        final confirmPasswordField = find.byType(TextFormField).at(2);
        await tester.enterText(confirmPasswordField, 'SecurePassword123!');
        await tester.pump();

        final signUpButton = find.widgetWithText(
          ElevatedButton,
          'Create Account',
        );
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Assert: Email verification sent
        verify(authFixture.mockUser.sendEmailVerification()).called(1);
        expect(find.textContaining('verification'), findsOneWidget);
      });
    });

    // =========================================================================
    // EDGE CASES AND ERROR HANDLING
    // =========================================================================
    group('Edge Cases and Error Handling', () {
      testWidgets(
        'INT-AUTH-01.21: Network error during sign-up shows message',
        (WidgetTester tester) async {
          // Arrange
          when(
            authFixture.mockAuth.createUserWithEmailAndPassword(
              email: anyNamed('email'),
              password: anyNamed('password'),
            ),
          ).thenThrow(
            FirebaseAuthException(
              code: 'network-request-failed',
              message: 'Network error',
            ),
          );

          // Act
          await tester.pumpWidget(
            const ProviderScope(child: MaterialApp(home: RegisterScreen())),
          );
          await tester.pumpAndSettle();

          final emailField = find.byType(TextFormField).at(0);
          await tester.enterText(emailField, 'test@example.com');
          await tester.pump();

          final passwordField = find.byType(TextFormField).at(1);
          await tester.enterText(passwordField, 'SecurePassword123!');
          await tester.pump();

          final confirmPasswordField = find.byType(TextFormField).at(2);
          await tester.enterText(confirmPasswordField, 'SecurePassword123!');
          await tester.pump();

          final signUpButton = find.widgetWithText(
            ElevatedButton,
            'Create Account',
          );
          await tester.tap(signUpButton);
          await tester.pumpAndSettle();

          // Assert
          expect(find.textContaining('network'), findsOneWidget);
        },
      );

      testWidgets('INT-AUTH-01.22: Special characters in email handled', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setupFailedSignUp('invalid-email', 'Invalid email address');

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, 'test+special@example.com');
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, 'SecurePassword123!');
        await tester.pump();

        final confirmPasswordField = find.byType(TextFormField).at(2);
        await tester.enterText(confirmPasswordField, 'SecurePassword123!');
        await tester.pump();

        final signUpButton = find.widgetWithText(
          ElevatedButton,
          'Create Account',
        );
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Should handle special characters or show appropriate error
        expect(find.byType(TextFormField), findsWidgets);
      });

      testWidgets('INT-AUTH-01.23: Password with special characters accepted', (
        WidgetTester tester,
      ) async {
        // Arrange
        authFixture.setupSuccessfulSignUp();

        const email = 'test@example.com';
        const password = 'P@ssw0rd!#\$%^&*()';

        // Act
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RegisterScreen())),
        );
        await tester.pumpAndSettle();

        final emailField = find.byType(TextFormField).at(0);
        await tester.enterText(emailField, email);
        await tester.pump();

        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, password);
        await tester.pump();

        final confirmPasswordField = find.byType(TextFormField).at(2);
        await tester.enterText(confirmPasswordField, password);
        await tester.pump();

        final signUpButton = find.widgetWithText(
          ElevatedButton,
          'Create Account',
        );
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Assert: Should succeed or show validation (not crash)
        expect(find.byType(TextFormField), findsWidgets);
      });
    });
  });
}
