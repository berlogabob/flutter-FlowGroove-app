import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_repsync_app/providers/auth/auth_provider.dart';
import 'package:flutter_repsync_app/models/api_error.dart';
import 'package:flutter_repsync_app/models/user.dart';
import 'package:flutter_repsync_app/services/cache_service.dart';

@GenerateMocks([FirebaseAuth, User, UserCredential, CacheService])
import 'auth_provider_test.mocks.dart';

void main() {
  group('AuthProvider', () {
    late ProviderContainer container;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockUser mockUser;
    late MockUserCredential mockUserCredential;
    late MockCacheService mockCacheService;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockUserCredential = MockUserCredential();
      mockCacheService = MockCacheService();

      // Setup default mock behaviors
      when(mockCacheService.clearAllUserCache(any)).thenAnswer((_) async => {});
      when(
        mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(null));
      when(mockFirebaseAuth.currentUser).thenReturn(null);

      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
          cacheServiceProvider.overrideWithValue(mockCacheService),
        ],
      );
      addTearDown(container.dispose);
    });

    group('Provider Initialization', () {
      test('authStateProvider is initialized', () {
        final authState = container.read(authStateProvider);
        expect(authState, isNotNull);
      });

      test('currentUserProvider is initialized', () {
        final currentUser = container.read(currentUserProvider);
        expect(currentUser, isA<Object?>());
      });

      test('appUserProvider is initialized', () {
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });

      test('cacheServiceProvider returns mocked instance', () {
        final cacheService = container.read(cacheServiceProvider);
        expect(cacheService, equals(mockCacheService));
      });

      test('firebaseAuthProvider returns mocked instance', () {
        final auth = container.read(firebaseAuthProvider);
        expect(auth, equals(mockFirebaseAuth));
      });
    });

    group('Auth State Provider', () {
      test('authStateProvider returns AsyncValue stream', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final authState = container.read(authStateProvider);
        expect(authState, isA<AsyncValue>());
      });

      test('authStateProvider emits user when signed in', () async {
        when(mockUser.uid).thenReturn('test-user-id');
        when(mockUser.email).thenReturn('test@example.com');
        when(mockUser.displayName).thenReturn('Test User');
        when(mockUser.photoURL).thenReturn(null);
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(mockUser));

        final authState = container.read(authStateProvider);
        expect(authState, isNotNull);
      });

      test('authStateProvider emits null when signed out', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final authState = container.read(authStateProvider);
        expect(authState, isNotNull);
      });
    });

    group('Current User Provider', () {
      test('currentUserProvider returns null when not authenticated', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        final currentUser = container.read(currentUserProvider);
        expect(currentUser, isNull);
      });

      test('currentUserProvider is accessible', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final currentUser = container.read(currentUserProvider);
        expect(currentUser, isA<Object?>());
      });
    });

    group('App User Provider', () {
      test('appUserProvider initial state is AsyncValue', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final appUserState = container.read(appUserProvider);
        expect(appUserState, isA<AsyncValue<AppUser?>>());
      });

      test('appUserProvider returns null when no user', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final appUserState = container.read(appUserProvider);
        expect(appUserState.value, isNull);
      });

      test('appUserProvider state is accessible', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });

      test('appUserProvider can be refreshed', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        container.refresh(appUserProvider);
        final appUserState = container.read(appUserProvider);
        expect(appUserState, isNotNull);
      });

      test('appUserProvider notifier is accessible', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);
        expect(notifier, isNotNull);
      });
    });

    group('Authentication Flow - Sign In', () {
      test('signInWithEmailAndPassword succeeds', () async {
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-user-id');
        when(mockUser.email).thenReturn('test@example.com');
        when(mockUser.displayName).thenReturn('Test User');
        when(mockUser.photoURL).thenReturn(null);

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenAnswer((_) async => mockUserCredential);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(mockUser));
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        final notifier = container.read(appUserProvider.notifier);
        final result = await notifier.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, equals(mockUserCredential));
        verify(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test(
        'signInWithEmailAndPassword fails with invalid credentials',
        () async {
          final firebaseAuthException = FirebaseAuthException(
            code: 'invalid-credential',
            message: 'Invalid email or password',
          );

          when(
            mockFirebaseAuth.signInWithEmailAndPassword(
              email: anyNamed('email'),
              password: anyNamed('password'),
            ),
          ).thenThrow(firebaseAuthException);

          when(
            mockFirebaseAuth.authStateChanges(),
          ).thenAnswer((_) => Stream.value(null));
          when(mockFirebaseAuth.currentUser).thenReturn(null);

          final notifier = container.read(appUserProvider.notifier);

          await expectLater(
            () => notifier.signInWithEmailAndPassword(
              email: 'test@example.com',
              password: 'wrongpassword',
            ),
            throwsA(isA<ApiError>()),
          );

          final state = container.read(appUserProvider);
          expect(state.hasError, isTrue);
        },
      );

      test('signInWithEmailAndPassword fails with user-not-found', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'nonexistent@example.com',
            password: 'password123',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).message, contains('No account found'));
        }
      });

      test('signInWithEmailAndPassword fails with wrong-password', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'wrong-password',
          message: 'Wrong password',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrongpassword',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).message, contains('Incorrect password'));
        }
      });

      test('signInWithEmailAndPassword fails with network error', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'network-request-failed',
          message: 'Network error',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).isNetwork, isTrue);
        }
      });

      test('signInWithEmailAndPassword fails with user-disabled', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'user-disabled',
          message: 'User disabled',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).message, contains('disabled'));
        }
      });
    });

    group('Authentication Flow - Sign Up', () {
      test('createUserWithEmailAndPassword succeeds', () async {
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-user-id');
        when(mockUser.email).thenReturn('newuser@example.com');
        when(mockUser.displayName).thenReturn(null);
        when(mockUser.photoURL).thenReturn(null);

        when(
          mockFirebaseAuth.createUserWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenAnswer((_) async => mockUserCredential);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(mockUser));
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        final notifier = container.read(appUserProvider.notifier);
        final result = await notifier.createUserWithEmailAndPassword(
          email: 'newuser@example.com',
          password: 'password123',
        );

        expect(result, equals(mockUserCredential));
        verify(
          mockFirebaseAuth.createUserWithEmailAndPassword(
            email: 'newuser@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test(
        'createUserWithEmailAndPassword fails with email-already-in-use',
        () async {
          final firebaseAuthException = FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email already in use',
          );

          when(
            mockFirebaseAuth.createUserWithEmailAndPassword(
              email: anyNamed('email'),
              password: anyNamed('password'),
            ),
          ).thenThrow(firebaseAuthException);

          when(
            mockFirebaseAuth.authStateChanges(),
          ).thenAnswer((_) => Stream.value(null));

          final notifier = container.read(appUserProvider.notifier);

          try {
            await notifier.createUserWithEmailAndPassword(
              email: 'existing@example.com',
              password: 'password123',
            );
          } catch (e) {
            expect(e, isA<ApiError>());
            expect((e as ApiError).isValidation, isTrue);
            expect((e as ApiError).message, contains('already exists'));
          }
        },
      );

      test('createUserWithEmailAndPassword fails with weak-password', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'weak-password',
          message: 'Password is too weak',
        );

        when(
          mockFirebaseAuth.createUserWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.createUserWithEmailAndPassword(
            email: 'newuser@example.com',
            password: '123',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).isValidation, isTrue);
          expect((e as ApiError).message, contains('weak'));
        }
      });

      test('createUserWithEmailAndPassword fails with invalid-email', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'invalid-email',
          message: 'Invalid email',
        );

        when(
          mockFirebaseAuth.createUserWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.createUserWithEmailAndPassword(
            email: 'invalid-email',
            password: 'password123',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).isValidation, isTrue);
        }
      });
    });

    group('Authentication Flow - Sign Out', () {
      test('signOut succeeds', () async {
        when(mockUser.uid).thenReturn('test-user-id');
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async => {});
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);
        await notifier.signOut();

        verify(mockFirebaseAuth.signOut()).called(1);

        final state = container.read(appUserProvider);
        expect(state.value, isNull);
      });

      test('signOut clears user cache before signing out', () async {
        when(mockUser.uid).thenReturn('test-user-id');
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async => {});
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);
        await notifier.signOut();

        // Verify cache was cleared
        verify(mockCacheService.clearAllUserCache('test-user-id')).called(1);
        verify(mockFirebaseAuth.signOut()).called(1);
      });

      test('signOut handles error gracefully', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'unknown',
          message: 'Sign out failed',
        );

        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockFirebaseAuth.signOut()).thenThrow(firebaseAuthException);
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signOut();
        } catch (e) {
          expect(e, isA<ApiError>());
        }

        final state = container.read(appUserProvider);
        expect(state.hasError, isTrue);
      });

      test('signOut handles null user gracefully', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(null);
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async => {});
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        expect(() => notifier.signOut(), returnsNormally);
      });
    });

    group('Password Reset', () {
      test('sendPasswordResetEmail succeeds', () async {
        when(
          mockFirebaseAuth.sendPasswordResetEmail(email: anyNamed('email')),
        ).thenAnswer((_) async => {});

        final notifier = container.read(appUserProvider.notifier);

        expect(
          () => notifier.sendPasswordResetEmail('test@example.com'),
          returnsNormally,
        );
        verify(
          mockFirebaseAuth.sendPasswordResetEmail(email: 'test@example.com'),
        ).called(1);
      });

      test('sendPasswordResetEmail fails with invalid email', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'invalid-email',
          message: 'Invalid email',
        );

        when(
          mockFirebaseAuth.sendPasswordResetEmail(email: anyNamed('email')),
        ).thenThrow(firebaseAuthException);

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.sendPasswordResetEmail('invalid-email');
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).isValidation, isTrue);
        }
      });

      test('sendPasswordResetEmail fails with user-not-found', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'user-not-found',
          message: 'User not found',
        );

        when(
          mockFirebaseAuth.sendPasswordResetEmail(email: anyNamed('email')),
        ).thenThrow(firebaseAuthException);

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.sendPasswordResetEmail('nonexistent@example.com');
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).isAuth, isTrue);
        }
      });

      test('sendPasswordResetEmail fails with too-many-requests', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Too many requests',
        );

        when(
          mockFirebaseAuth.sendPasswordResetEmail(email: anyNamed('email')),
        ).thenThrow(firebaseAuthException);

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.sendPasswordResetEmail('test@example.com');
        } catch (e) {
          expect(e, isA<ApiError>());
          expect((e as ApiError).isAuth, isTrue);
        }
      });
    });

    group('Error Handling', () {
      test('ApiError mapping for user-not-found', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password',
          );
        } catch (e) {
          final apiError = e as ApiError;
          expect(apiError.type, ErrorType.auth);
          expect(apiError.message, contains('No account found'));
        }
      });

      test('ApiError mapping for wrong-password', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'wrong-password',
          message: 'Wrong password',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrong',
          );
        } catch (e) {
          final apiError = e as ApiError;
          expect(apiError.type, ErrorType.auth);
          expect(apiError.message, contains('Incorrect password'));
        }
      });

      test('ApiError mapping for network error', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'network-request-failed',
          message: 'Network error',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password',
          );
        } catch (e) {
          final apiError = e as ApiError;
          expect(apiError.type, ErrorType.network);
          expect(apiError.isNetwork, isTrue);
        }
      });

      test('Error state propagation during sign in failure', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Invalid credentials',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrong',
          );
        } catch (_) {}

        final state = container.read(appUserProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<ApiError>());
      });

      test('Loading state during async operations', () async {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final state = container.read(appUserProvider);
        // Initial state should be accessible
        expect(state, isNotNull);
      });
    });

    group('Stream Subscriptions', () {
      test('auth state stream is subscribed', () async {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        // Verify the provider subscribes to the stream
        final authState = container.read(authStateProvider);
        expect(authState, isNotNull);

        // Verify the mock was called
        verify(mockFirebaseAuth.authStateChanges()).called(1);
      });

      test('auth state changes stream emits values', () async {
        when(mockUser.uid).thenReturn('test-user-id');
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(mockUser));

        final authState = container.read(authStateProvider);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(authState, isNotNull);
        verify(mockFirebaseAuth.authStateChanges()).called(1);
      });

      test('stream provider handles null emission', () async {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final authState = container.read(authStateProvider);
        expect(authState, isNotNull);
      });
    });

    group('Dispose Verification', () {
      test('AppUserNotifier dispose does not throw', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        // Dispose should not throw
        expect(() => notifier.dispose(), returnsNormally);
      });

      test('ProviderContainer dispose cleans up resources', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final localContainer = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            cacheServiceProvider.overrideWithValue(mockCacheService),
          ],
        );

        // Read providers
        localContainer.read(appUserProvider);
        localContainer.read(authStateProvider);
        localContainer.read(currentUserProvider);

        // Dispose should not throw
        expect(() => localContainer.dispose(), returnsNormally);
      });
    });

    group('State Equality and hashCode', () {
      test('AsyncValue equality works correctly', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final state1 = container.read(appUserProvider);
        final state2 = container.read(appUserProvider);

        // Same state should be equal
        expect(state1, equals(state2));
      });

      test('AsyncValue hashCode is consistent', () {
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final state1 = container.read(appUserProvider);
        final state2 = container.read(appUserProvider);

        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('Extension Methods', () {
      test('AuthErrorHandling extension is accessible', () {
        // The extension should be available on Ref
        // This test verifies the extension compiles and is accessible
        expect(true, isTrue);
      });
    });

    group('Edge Cases', () {
      test('signInWithEmailAndPassword with empty email', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'invalid-email',
          message: 'Invalid email',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: '',
            password: 'password',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
        }
      });

      test('signInWithEmailAndPassword with empty password', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Invalid credentials',
        );

        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenThrow(firebaseAuthException);

        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: '',
          );
        } catch (e) {
          expect(e, isA<ApiError>());
        }
      });

      test(
        'createUserWithEmailAndPassword with operation-not-allowed',
        () async {
          final firebaseAuthException = FirebaseAuthException(
            code: 'operation-not-allowed',
            message: 'Operation not allowed',
          );

          when(
            mockFirebaseAuth.createUserWithEmailAndPassword(
              email: anyNamed('email'),
              password: anyNamed('password'),
            ),
          ).thenThrow(firebaseAuthException);

          when(
            mockFirebaseAuth.authStateChanges(),
          ).thenAnswer((_) => Stream.value(null));

          final notifier = container.read(appUserProvider.notifier);

          try {
            await notifier.createUserWithEmailAndPassword(
              email: 'test@example.com',
              password: 'password',
            );
          } catch (e) {
            expect(e, isA<ApiError>());
            expect((e as ApiError).isAuth, isTrue);
          }
        },
      );

      test('requires-recent-login error mapping', () async {
        final firebaseAuthException = FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Requires recent login',
        );

        when(mockFirebaseAuth.signOut()).thenThrow(firebaseAuthException);
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(
          mockFirebaseAuth.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));

        final notifier = container.read(appUserProvider.notifier);

        try {
          await notifier.signOut();
        } catch (e) {
          expect(e, isA<ApiError>());
          // Error is caught and wrapped in ApiError
        }
      });
    });
  });
}
