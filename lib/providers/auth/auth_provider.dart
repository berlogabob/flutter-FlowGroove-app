import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/api_error.dart';
import '../../models/user.dart';
import '../../services/cache_service.dart';
import '../../services/firestore_service.dart';

/// Provider for the FirebaseAuth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for the CacheService.
/// Exported from data_providers but also available here for auth operations.
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

/// Provider that returns the current Firebase user as an AsyncValue.
///
/// This returns the same AsyncValue as authStateProvider,
/// providing a convenient way to access the current user with proper
/// loading/error state handling.
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
          String? photoURL = user.photoURL;

          if (displayName.isEmpty) {
            // Use email or fallback to 'User'
            final emailPrefix = user.email?.split('@').first ?? 'User';
            displayName = emailPrefix.isNotEmpty ? emailPrefix : 'User';
          }

          // Load Telegram photo if consent given
          _loadTelegramProfile(user.uid).then((
            Map<String, dynamic>? telegramData,
          ) {
            if (telegramData != null) {
              // Use Telegram name if no Firebase name
              if (displayName == 'User' &&
                  telegramData['telegramUsername'] != null) {
                displayName = telegramData['telegramUsername'] as String;
              }
              // Use Telegram photo if available
              photoURL = telegramData['telegramPhotoURL'] as String?;

              // Update state with Telegram data
              state = AsyncValue.data(
                AppUser(
                  uid: user.uid,
                  email: user.email,
                  displayName: displayName,
                  photoURL: photoURL,
                  createdAt: DateTime.now(),
                ),
              );
            }
          });

          return AsyncValue.data(
            AppUser(
              uid: user.uid,
              email: user.email,
              displayName: displayName,
              photoURL: photoURL,
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

  /// Load Telegram profile data if user gave consent
  Future<Map<String, dynamic>?> _loadTelegramProfile(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['telegramConsent'] == true) {
          return {
            'telegramUsername': data['telegramUsername'],
            'telegramPhotoURL': data['telegramPhotoURL'],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error loading Telegram profile: $e');
      return null;
    }
  }

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

  /// Checks for a pending join code stored before login redirect.
  ///
  /// Returns the join code if one was stored, null otherwise.
  /// Clears the stored code after retrieving it.
  static Future<String?> getAndClearPendingJoinCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('pending_join_code');
    if (code != null) {
      await prefs.remove('pending_join_code');
    }
    return code;
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

  /// Signs in with Twitter.
  ///
  /// Updates the user's base tags (role tags like guitarist, vocalist, etc.)
  ///
  /// Throws [ApiError] if update fails.
  Future<void> updateBaseTags(List<String> tags) async {
    final currentUser = state.value;
    if (currentUser == null) {
      throw ApiError.auth(message: 'No user logged in');
    }

    try {
      final updatedUser = currentUser.copyWith(baseTags: tags);
      final firestore = FirestoreService();
      await firestore.saveUser(updatedUser);
      state = AsyncValue.data(updatedUser);
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
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
