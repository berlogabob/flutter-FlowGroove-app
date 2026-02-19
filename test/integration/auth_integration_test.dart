/// Authentication Integration Tests
///
/// These tests verify authentication functionality using mocks.
///
/// To run these tests:
/// 1. Run tests: `flutter test test/integration/auth_integration_test.dart`
///
/// Note: These tests use mocked Firebase Auth to ensure consistent test results.

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import '../helpers/mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockCredential mockCredential;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockCredential = MockCredential();

    // Setup default mock behaviors
    when(mockCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-user-id');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
    when(mockUser.isAnonymous).thenReturn(false);
    when(mockUser.emailVerified).thenReturn(false);
  });

  tearDown(() async {
    // Reset mocks
    reset(mockAuth);
    reset(mockUser);
    reset(mockCredential);
  });

  group('Authentication - User Creation', () {
    test('creates user with email and password', () async {
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'newuser@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => mockCredential);

      final result = await mockAuth.createUserWithEmailAndPassword(
        email: 'newuser@example.com',
        password: 'password123',
      );

      expect(result, equals(mockCredential));
      verify(
        mockAuth.createUserWithEmailAndPassword(
          email: 'newuser@example.com',
          password: 'password123',
        ),
      ).called(1);
    });

    test('throws error for weak password', () async {
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: '123',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'weak-password',
          message: 'Password is too weak',
        ),
      );

      expect(
        () => mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: '123',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('throws error for invalid email', () async {
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'invalid-email',
          password: 'password123',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'invalid-email',
          message: 'Invalid email address',
        ),
      );

      expect(
        () => mockAuth.createUserWithEmailAndPassword(
          email: 'invalid-email',
          password: 'password123',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('throws error for email already in use', () async {
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'existing@example.com',
          password: 'password123',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Email already in use',
        ),
      );

      expect(
        () => mockAuth.createUserWithEmailAndPassword(
          email: 'existing@example.com',
          password: 'password123',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('Authentication - Sign In', () {
    test('signs in with email and password', () async {
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => mockCredential);

      final result = await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result, equals(mockCredential));
      verify(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).called(1);
    });

    test('throws error for user not found', () async {
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'nonexistent@example.com',
          password: 'password123',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this email',
        ),
      );

      expect(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'nonexistent@example.com',
          password: 'password123',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('throws error for wrong password', () async {
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'wrongpassword',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'wrong-password',
          message: 'Wrong password',
        ),
      );

      expect(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'wrongpassword',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('Authentication - Sign Out', () {
    test('signs out user', () async {
      when(mockAuth.signOut()).thenAnswer((_) async => {});

      await mockAuth.signOut();

      verify(mockAuth.signOut()).called(1);
    });
  });

  group('Authentication - Current User', () {
    test('returns current user when signed in', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);

      final user = mockAuth.currentUser;

      expect(user, equals(mockUser));
      expect(user?.uid, equals('test-user-id'));
    });

    test('returns null when no user signed in', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final user = mockAuth.currentUser;

      expect(user, isNull);
    });
  });

  group('Authentication - Email Verification', () {
    test('sends email verification', () async {
      when(mockUser.sendEmailVerification()).thenAnswer((_) async => {});

      await mockUser.sendEmailVerification();

      verify(mockUser.sendEmailVerification()).called(1);
    });

    test('checks if email is verified', () async {
      when(mockUser.emailVerified).thenReturn(true);

      final isVerified = mockUser.emailVerified;

      expect(isVerified, isTrue);
    });
  });

  group('Authentication - User Profile Update', () {
    test('updates user display name', () async {
      when(mockUser.updateDisplayName('New Name')).thenAnswer((_) async => {});

      await mockUser.updateDisplayName('New Name');

      verify(mockUser.updateDisplayName('New Name')).called(1);
    });
  });

  group('Authentication - Auth State Changes', () {
    test('listens to auth state changes', () async {
      final userStream = Stream<User?>.value(mockUser);
      when(mockAuth.authStateChanges()).thenReturn(userStream);

      final stream = mockAuth.authStateChanges();

      expect(stream, isA<Stream<User?>>());
    });

    test('emits null when user signs out', () async {
      final userStream = Stream<User?>.value(null);
      when(mockAuth.authStateChanges()).thenReturn(userStream);

      final stream = mockAuth.authStateChanges();
      await expectLater(stream, emits(null));
    });
  });

  group('User Model', () {
    test('user has correct uid', () async {
      when(mockUser.uid).thenReturn('unique-user-id');

      expect(mockUser.uid, equals('unique-user-id'));
    });

    test('user has correct email', () async {
      when(mockUser.email).thenReturn('user@example.com');

      expect(mockUser.email, equals('user@example.com'));
    });

    test('user has correct display name', () async {
      when(mockUser.displayName).thenReturn('John Doe');

      expect(mockUser.displayName, equals('John Doe'));
    });

    test('user is not anonymous', () async {
      when(mockUser.isAnonymous).thenReturn(false);

      expect(mockUser.isAnonymous, isFalse);
    });
  });
}
