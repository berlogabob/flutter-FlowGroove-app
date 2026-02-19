import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_repsync_app/screens/auth/register_screen.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mocks.dart';
import 'login_screen_test.dart';

void main() {
  group('RegisterScreen', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
    });

    testWidgets('renders register screen with all elements', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Verify screen title
      expect(findText('Create Account'), findsOneWidget);
      
      // Verify header
      expect(findText('Join RepSync'), findsOneWidget);
      
      // Verify subtitle
      expect(findText('Create an account to manage your band repertoire'), findsOneWidget);
      
      // Verify email field
      expect(findText('Email'), findsOneWidget);
      
      // Verify password field
      expect(findText('Password'), findsOneWidget);
      
      // Verify confirm password field
      expect(findText('Confirm Password'), findsOneWidget);
      
      // Verify create account button
      expect(findText('Create Account'), findsOneWidget);
      
      // Verify sign in link
      expect(findText('Already have an account?'), findsOneWidget);
      expect(findText('Sign In'), findsOneWidget);
    });

    testWidgets('displays icons for all input fields', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Should have 3 lock icons (password fields) and 1 email icon
      verifyFoundN(findIcon(Icons.email_outlined), 1);
      verifyFoundN(findIcon(Icons.lock_outlined), 3);
    });

    testWidgets('allows entering email, password, and confirm password', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Find text fields
      final textFields = find.byType(TextFormField);
      
      // Enter email
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.pump();

      // Enter password
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pump();

      // Enter confirm password
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pump();

      // Verify text was entered
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows validation error for empty email', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Tap create account button without entering data
      await tester.tap(findText('Create Account'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Find email field and enter invalid email
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'invalid-email');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows validation error for empty password', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter email only
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('shows validation error for weak password', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter email and weak password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), '12345');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('shows validation error for empty confirm password', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter email and password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets('shows validation error for mismatched passwords', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter email and mismatched passwords
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password456');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pump();

      // Verify validation message appears
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows loading indicator when registering', (WidgetTester tester) async {
      // Setup mock to simulate async registration
      when(mockAuth.createUserWithEmailAndPassword(
        email: any as String,
        password: any as String,
      )).thenAnswer((_) async => createMockUserCredential());

      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter valid credentials
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pump();

      // Verify loading indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('navigates to login screen when tapping Sign In', (WidgetTester tester) async {
      bool didNavigate = false;
      
      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (_) => didNavigate = true),
        ],
      );

      // Tap Sign In button
      await tester.tap(findText('Sign In'));
      await tester.pump();

      // Verify navigation occurred
      expect(didNavigate, isTrue);
    });

    testWidgets('displays error message for email already in use', (WidgetTester tester) async {
      // Setup mock to throw auth error
      when(mockAuth.createUserWithEmailAndPassword(
        email: any as String,
        password: any as String,
      )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter valid credentials
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.text('This email is already registered'), findsOneWidget);
    });

    testWidgets('displays error message for invalid email', (WidgetTester tester) async {
      // Setup mock to throw auth error
      when(mockAuth.createUserWithEmailAndPassword(
        email: any as String,
        password: any as String,
      )).thenThrow(FirebaseAuthException(code: 'invalid-email'));

      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter valid credentials
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.text('Invalid email address'), findsOneWidget);
    });

    testWidgets('displays error message for weak password from Firebase', (WidgetTester tester) async {
      // Setup mock to throw auth error
      when(mockAuth.createUserWithEmailAndPassword(
        email: any as String,
        password: any as String,
      )).thenThrow(FirebaseAuthException(code: 'weak-password'));

      await pumpAppWidget(
        tester,
        const RegisterScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
        ],
      );

      // Enter valid credentials
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pump();

      // Tap create account button
      await tester.tap(findText('Create Account'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.text('Password is too weak'), findsOneWidget);
    });
  });
}
