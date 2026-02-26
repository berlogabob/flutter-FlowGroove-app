import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/api_error.dart';
import '../../models/user.dart';
import '../../services/cache_service.dart';

/// Provider for the FirebaseAuth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for the CacheService.
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Provider that watches the Firebase auth state.
///
/// Returns a stream of User? that emits the current user
/// whenever the auth state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Provider that returns the current Firebase user as AsyncValue.
///
/// FIX: Changed from returning User? to AsyncValue<User?> to properly
/// handle loading and error states without returning null.
///
/// Usage:
/// ```dart
/// // In widgets:
/// final userAsync = ref.watch(currentUserProvider);
/// userAsync.when(
///   data: (user) => Text(user?.email ?? 'Not logged in'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final currentUserProvider = Provider<AsyncValue<User?>>((ref) {
  return ref.watch(authStateProvider);
});

/// Provider for the AppUser state with error handling.
///
/// This provider watches the auth state and converts Firebase User
/// to AppUser, handling errors appropriately.
final appUserProvider = NotifierProvider<AppUserNotifier, AsyncValue<AppUser?>>(
  () {
    return AppUserNotifier();
  },
);

/// Notifier for managing AppUser state.
///
/// IMPORTANT: Properly disposes resources to prevent memory leaks.
class AppUserNotifier extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          String displayName = user.displayName ?? '';
          if (displayName.isEmpty) {
            // Use email or fallback to 'User'
            final emailPrefix = user.email?.split('@').first ?? 'User';
            displayName = emailPrefix.isNotEmpty ? emailPrefix : 'User';
          }
          return AsyncValue.data(
            AppUser(
              uid: user.uid,
              email: user.email,
              displayName: displayName.isNotEmpty ? displayName : 'User',
              photoURL: user.photoURL,
              createdAt: DateTime.now(),
            ),
          );
        }
        return const AsyncValue.data(null);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) {
        // Convert Firebase auth errors to ApiError
        final apiError = ApiError.fromException(error, stackTrace: stack);
        return AsyncValue.error(apiError, stack);
      },
    );
  }

  @override
  void dispose() {
    // No stream subscriptions to cancel
    // Riverpod automatically manages ref.watch subscriptions
  }

  /// Signs out the current user.
  ///
  /// Clears the user's cache before signing out.
  /// Throws [ApiError] if sign out fails.
  Future<void> signOut() async {
    try {
      // Get current user UID before signing out
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        // Clear cache for this user
        final cache = ref.read(cacheServiceProvider);
        await cache.clearAllUserCache(user.uid);
      }

      await ref.read(firebaseAuthProvider).signOut();
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e, stackTrace) {
      final apiError = _mapFirebaseAuthException(e);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }
  }

  /// Signs in with email and password.
  ///
  /// Throws [ApiError] if sign in fails.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      final apiError = _mapFirebaseAuthException(e);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }
  }

  /// Creates a new user with email and password.
  ///
  /// Throws [ApiError] if registration fails.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await ref
          .read(firebaseAuthProvider)
          .createUserWithEmailAndPassword(email: email, password: password);
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      final apiError = _mapFirebaseAuthException(e);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }
  }

  /// Sends a password reset email.
  ///
  /// Throws [ApiError] if the request fails.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await ref.read(firebaseAuthProvider).sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      final apiError = _mapFirebaseAuthException(e);
      throw apiError;
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      throw apiError;
    }
  }

  /// Maps Firebase Auth exceptions to ApiError with user-friendly messages.
  ApiError _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return ApiError.auth(
          message: 'No account found with this email address.',
          exception: e,
        );
      case 'wrong-password':
        return ApiError.auth(
          message: 'Incorrect password. Please try again.',
          exception: e,
        );
      case 'email-already-in-use':
        return ApiError.validation(
          message: 'An account with this email already exists.',
          exception: e,
        );
      case 'weak-password':
        return ApiError.validation(
          message: 'Password is too weak. Please use at least 6 characters.',
          exception: e,
        );
      case 'invalid-email':
        return ApiError.validation(
          message: 'Invalid email address.',
          exception: e,
        );
      case 'user-disabled':
        return ApiError.auth(
          message: 'This account has been disabled.',
          exception: e,
        );
      case 'requires-recent-login':
        return ApiError.auth(
          message: 'Please sign in again to perform this action.',
          exception: e,
        );
      case 'network-request-failed':
        return ApiError.network(
          message: 'Unable to connect. Please check your internet connection.',
          exception: e,
        );
      case 'too-many-requests':
        return ApiError.auth(
          message: 'Too many failed attempts. Please try again later.',
          exception: e,
        );
      case 'operation-not-allowed':
        return ApiError.auth(
          message: 'This sign-in method is not enabled.',
          exception: e,
        );
      default:
        return ApiError.fromException(e);
    }
  }
}

/// Extension on Ref for convenient auth error handling.
extension AuthErrorHandling on Ref {
  /// Handles a Firebase Auth exception by converting it to ApiError.
  ApiError handleAuthException(FirebaseAuthException e) {
    return AppUserNotifier()._mapFirebaseAuthException(e);
  }
}
