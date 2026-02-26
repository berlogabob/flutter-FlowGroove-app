import 'package:flutter/foundation.dart';
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
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  debugPrint('🔍 [AUTH_STATE] Setting up auth state listener');
  return auth.authStateChanges();
});

/// Provider that returns the current Firebase user.
/// 
/// ⚠️ BUG LOCATION: This can return null when authState is loading/error!
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  debugPrint('🔍 [CURRENT_USER] authState state: ${authState.isLoading ? 'LOADING' : authState.hasError ? 'ERROR' : 'DATA'}');
  
  final user = authState.value;
  debugPrint('🔍 [CURRENT_USER] user value: ${user == null ? 'NULL' : user.uid}');
  
  return user;
});

/// Provider for the AppUser state with error handling.
final appUserProvider = NotifierProvider<AppUserNotifier, AsyncValue<AppUser?>>(
  () {
    return AppUserNotifier();
  },
);

/// Notifier for managing AppUser state.
class AppUserNotifier extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() {
    debugPrint('🔍 [APP_USER_NOTIFIER] build() called');
    final authState = ref.watch(authStateProvider);
    debugPrint('🔍 [APP_USER_NOTIFIER] authState: ${authState.isLoading ? 'LOADING' : authState.hasError ? 'ERROR' : 'DATA'}');

    return authState.when(
      data: (user) {
        debugPrint('🔍 [APP_USER_NOTIFIER] data callback: user=${user == null ? 'NULL' : user.uid}');
        if (user != null) {
          String displayName = user.displayName ?? '';
          if (displayName.isEmpty) {
            final emailPrefix = user.email?.split('@').first ?? 'User';
            displayName = emailPrefix.isNotEmpty ? emailPrefix : 'User';
          }
          final appUser = AppUser(
            uid: user.uid,
            email: user.email,
            displayName: displayName.isNotEmpty ? displayName : 'User',
            photoURL: user.photoURL,
            createdAt: DateTime.now(),
          );
          debugPrint('🔍 [APP_USER_NOTIFIER] Created AppUser: ${appUser.uid}');
          return AsyncValue.data(appUser);
        }
        debugPrint('🔍 [APP_USER_NOTIFIER] Returning null AppUser');
        return const AsyncValue.data(null);
      },
      loading: () {
        debugPrint('🔍 [APP_USER_NOTIFIER] Loading state');
        return const AsyncValue.loading();
      },
      error: (error, stack) {
        debugPrint('🔍 [APP_USER_NOTIFIER] Error state: $error');
        final apiError = ApiError.fromException(error, stackTrace: stack);
        return AsyncValue.error(apiError, stack);
      },
    );
  }

  @override
  void dispose() {
    debugPrint('🔍 [APP_USER_NOTIFIER] dispose() called');
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    debugPrint('🔍 [APP_USER_NOTIFIER] signOut() called');
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      debugPrint('🔍 [APP_USER_NOTIFIER] signOut: currentUser=${user?.uid ?? 'NULL'}');
      
      if (user != null) {
        final cache = ref.read(cacheServiceProvider);
        await cache.clearAllUserCache(user.uid);
      }

      await ref.read(firebaseAuthProvider).signOut();
      debugPrint('🔍 [APP_USER_NOTIFIER] signOut: Success');
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('🔍 [APP_USER_NOTIFIER] signOut: FirebaseAuthException: $e');
      final apiError = _mapFirebaseAuthException(e);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    } catch (e, stackTrace) {
      debugPrint('🔍 [APP_USER_NOTIFIER] signOut: Exception: $e');
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }
  }

  /// Signs in with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    debugPrint('🔍 [APP_USER_NOTIFIER] signInWithEmailAndPassword() called');
    debugPrint('🔍 [APP_USER_NOTIFIER] Email: $email');
    
    try {
      debugPrint('🔍 [APP_USER_NOTIFIER] Calling Firebase signInWithEmailAndPassword');
      final credential = await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      debugPrint('🔍 [APP_USER_NOTIFIER] Firebase signIn success: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('🔍 [APP_USER_NOTIFIER] FirebaseAuthException: ${e.code} - ${e.message}');
      final apiError = _mapFirebaseAuthException(e);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    } catch (e, stackTrace) {
      debugPrint('🔍 [APP_USER_NOTIFIER] Exception: $e');
      debugPrint('🔍 [APP_USER_NOTIFIER] Stack: $stackTrace');
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }
  }

  /// Creates a new user with email and password.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    debugPrint('🔍 [APP_USER_NOTIFIER] createUserWithEmailAndPassword() called');
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
  Future<void> sendPasswordResetEmail(String email) async {
    debugPrint('🔍 [APP_USER_NOTIFIER] sendPasswordResetEmail() called');
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

  /// Maps Firebase Auth exceptions to ApiError.
  ApiError _mapFirebaseAuthException(FirebaseAuthException e) {
    debugPrint('🔍 [APP_USER_NOTIFIER] _mapFirebaseAuthException: ${e.code}');
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
