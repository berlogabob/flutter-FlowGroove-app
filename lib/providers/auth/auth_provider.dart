import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/api_error.dart';
import '../../models/user.dart';
import '../../services/analytics_service.dart';
import '../../services/cache_service.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/music_role_icon.dart';

/// Provider for the FirebaseAuth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for the FirebaseFirestore instance.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Lightweight adapter used to override analytics calls in tests.
class AnalyticsClient {
  Future<void> logLogin({required String loginMethod}) {
    return AnalyticsService.logLogin(loginMethod: loginMethod);
  }

  Future<void> logLoginSuccess({required String loginMethod}) {
    return AnalyticsService.logLoginSuccess(loginMethod: loginMethod);
  }

  Future<void> logDemoLogin() {
    return AnalyticsService.logDemoLogin();
  }

  Future<void> setUserProperties({
    required AppUser user,
    required int bandCount,
    required int songCount,
    required int setlistCount,
  }) {
    return AnalyticsService.setUserProperties(
      user: user,
      bandCount: bandCount,
      songCount: songCount,
      setlistCount: setlistCount,
    );
  }
}

final analyticsClientProvider = Provider<AnalyticsClient>((ref) {
  return AnalyticsClient();
});

/// Storage boundary for pending invite codes captured before auth.
class PendingJoinCodeStore {
  /// Persists an invite code captured before the user authenticated (e.g. from
  /// a shared join link opened while logged out), so the login flow can resume
  /// the join afterwards.
  Future<void> setPendingJoinCode(String code) async {
    await secureStorage.write(key: 'pending_join_code', value: code);
  }

  Future<String?> getAndClearPendingJoinCode() async {
    final code = await secureStorage.read(key: 'pending_join_code');
    if (code != null) {
      await secureStorage.delete(key: 'pending_join_code');
    }
    return code;
  }
}

final pendingJoinCodeStoreProvider = Provider<PendingJoinCodeStore>((ref) {
  return PendingJoinCodeStore();
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
  try {
    return ref.watch(firebaseAuthProvider).authStateChanges();
  } catch (e) {
    debugPrint(
      'FirebaseAuth is unavailable for authStateProvider; '
      'falling back to signed-out state.',
    );
    return Stream.value(null);
  }
});

/// Provider that returns the current Firebase user as an AsyncValue.
///
/// This returns the same AsyncValue as authStateProvider,
/// providing a convenient way to access the current user with proper
/// loading/error state handling.
final currentUserProvider = Provider<AsyncValue<User?>>((ref) {
  return ref.watch(authStateProvider);
});

/// Live users/{uid} document for the signed-in user.
///
/// A snapshot stream (not a one-shot get) so avatar/role changes — including
/// server-side ones like Telegram/Google avatar imports — propagate to every
/// screen without an app restart (#91).
final userDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  try {
    return ref
        .watch(firebaseFirestoreProvider)
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  } catch (_) {
    return Stream.value(null);
  }
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
  /// Tracks which uid analytics user-properties were synced for, so the sync
  /// runs once per sign-in instead of on every users/{uid} emission.
  String? _analyticsSyncedUid;

  @override
  AsyncValue<AppUser?> build() {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const AsyncValue.data(null);

        String displayName = user.displayName ?? '';
        if (displayName.isEmpty) {
          // Use email or fallback to 'User'
          final emailPrefix = user.email?.split('@').first ?? 'User';
          displayName = emailPrefix.isNotEmpty ? emailPrefix : 'User';
        }

        // Compose from the LIVE users/{uid} doc: every doc change rebuilds
        // the AppUser, so avatar/role updates reach all screens without an
        // app restart (#91). While the doc is still loading (or missing),
        // fall back to auth-only data.
        final data = ref.watch(userDocProvider).asData?.value;
        _syncAnalytics(user, data);

        if (data == null) {
          return AsyncValue.data(
            AppUser(
              uid: user.uid,
              email: user.email,
              displayName: displayName,
              photoURL: user.photoURL,
              createdAt: DateTime.now(),
            ),
          );
        }

        final telegramConsent = data['telegramConsent'] == true;
        final telegramUsername =
            telegramConsent ? data['telegramUsername'] as String? : null;
        final telegramPhotoURL =
            telegramConsent ? data['telegramPhotoURL'] as String? : null;

        if (displayName == 'User' && telegramUsername != null) {
          displayName = telegramUsername;
        }
        // Avatar precedence: the doc's photoURL is the user's chosen avatar
        // and is authoritative; fall back to Telegram, then auth photo.
        final photoURL = (data['photoURL'] as String?) ??
            telegramPhotoURL ??
            user.photoURL;

        return AsyncValue.data(
          AppUser(
            uid: user.uid,
            email: user.email,
            displayName: displayName,
            photoURL: photoURL,
            accessRole: (data['accessRole'] as String?) ?? 'member',
            musicRoles:
                List<String>.from((data['musicRoles'] as List?) ?? const []),
            systemTags:
                List<String>.from((data['systemTags'] as List?) ?? const []),
            createdAt: DateTime.now(),
          ),
        );
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) {
        // Convert Firebase auth errors to ApiError
        final apiError = ApiError.fromException(error, stackTrace: stack);
        return AsyncValue.error(apiError, stack);
      },
    );
  }

  /// Syncs analytics user-properties once per signed-in uid.
  void _syncAnalytics(User user, Map<String, dynamic>? data) {
    if (data == null || _analyticsSyncedUid == user.uid) return;
    _analyticsSyncedUid = user.uid;

    final bandCount = (data['bandIds'] as List?)?.length ?? 0;
    final analytics = ref.read(analyticsClientProvider);
    final snapshot = AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      accessRole: (data['accessRole'] as String?) ?? 'member',
      musicRoles: List<String>.from((data['musicRoles'] as List?) ?? const []),
      systemTags: List<String>.from((data['systemTags'] as List?) ?? const []),
      bandIds: List.generate(bandCount, (i) => 'band_$i'),
      createdAt: DateTime.now(),
    );
    Future(() async {
      try {
        await analytics.setUserProperties(
          user: snapshot,
          bandCount: bandCount,
          songCount: 0,
          setlistCount: 0,
        );
      } catch (e) {
        debugPrint('Error setting user properties: $e');
      }
    });
  }

  FirebaseFirestore? _readFirestoreIfAvailable() {
    try {
      return ref.read(firebaseFirestoreProvider);
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth _readFirebaseAuthOrThrow() {
    try {
      return ref.read(firebaseAuthProvider);
    } catch (e, stackTrace) {
      final apiError = ApiError.auth(
        message: 'Firebase Auth is not initialized.',
        exception: e,
        stackTrace: stackTrace,
      );
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
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
      final auth = _readFirebaseAuthOrThrow();
      // Get current user UID before signing out
      final user = auth.currentUser;
      if (user != null) {
        // Clear cache for this user
        final cache = ref.read(cacheServiceProvider);
        await cache.clearAllUserCache(user.uid);
      }

      await auth.signOut();
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
      final credential = await _readFirebaseAuthOrThrow()
          .signInWithEmailAndPassword(email: email, password: password);
      // Security rules read users/{uid}.accessRole; a missing doc blocks band
      // create/join and other writes. Backfill it for accounts created before
      // this was ensured.
      await _ensureUserDocument(credential.user);
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

  /// OAuth **Web** client ID used as the `serverClientId` for google_sign_in v7.
  ///
  /// Unlike v6, the v7 Android plugin does NOT auto-read the
  /// google-services-generated `default_web_client_id`, so without this the
  /// returned account has a null ID token and Firebase sign-in silently fails
  /// (account picker shows, then bounces back to the login screen). This is the
  /// public Web client from `google-services.json` (`client_type: 3`); override
  /// per environment with `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '703941154390-kq214etvh0r0ka6ahs01gbi5hhd5ii66.apps.googleusercontent.com',
  );

  /// google_sign_in v7 requires a one-time [GoogleSignIn.initialize] before
  /// any authentication call. We pass [serverClientId] so the returned account
  /// carries an ID token whose audience Firebase accepts.
  static bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized(GoogleSignIn googleSignIn) async {
    if (_googleSignInInitialized) return;
    await googleSignIn.initialize(
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    );
    _googleSignInInitialized = true;
  }

  /// Signs in with Google.
  ///
  /// On web this uses Firebase's popup flow; on mobile it uses the
  /// `google_sign_in` plugin to obtain an OAuth credential. After sign-in it
  /// ensures a Firestore user document exists (security rules read
  /// `users/{uid}.accessRole`, so a missing doc would block all writes).
  ///
  /// Throws [ApiError] if sign in fails or is cancelled.
  Future<UserCredential> signInWithGoogle() async {
    try {
      final auth = _readFirebaseAuthOrThrow();
      late final UserCredential credential;

      if (kIsWeb) {
        credential = await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        // google_sign_in v7: singleton + initialize() + authenticate().
        final googleSignIn = GoogleSignIn.instance;
        await _ensureGoogleSignInInitialized(googleSignIn);

        final GoogleSignInAccount googleUser;
        try {
          googleUser = await googleSignIn.authenticate();
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            // User aborted the Google sign-in sheet.
            throw ApiError.auth(message: 'Google sign-in was cancelled.');
          }
          rethrow;
        }

        // v7 only exposes an ID token here; that is sufficient for Firebase.
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          throw ApiError.auth(
            message: 'Google sign-in failed: missing ID token.',
          );
        }
        final oauthCredential = GoogleAuthProvider.credential(idToken: idToken);
        credential = await auth.signInWithCredential(oauthCredential);
      }

      await _ensureUserDocument(credential.user);
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      final apiError = _mapFirebaseAuthException(e);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    } on ApiError {
      rethrow;
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }
  }

  /// Ensures a Firestore user document exists for [user], creating a default
  /// one (accessRole `member`) on first social sign-in.
  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;
    final firestore = _readFirestoreIfAvailable();
    if (firestore == null) return;
    try {
      final docRef = firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (doc.exists) return;

      final fallbackName = user.email?.split('@').first;
      final appUser = AppUser(
        uid: user.uid,
        email: user.email,
        displayName: (user.displayName?.isNotEmpty ?? false)
            ? user.displayName
            : (fallbackName?.isNotEmpty ?? false)
            ? fallbackName
            : 'User',
        photoURL: user.photoURL,
        createdAt: DateTime.now(),
      );
      await docRef.set(appUser.toJson());
    } catch (e) {
      debugPrint('Error ensuring user document: $e');
    }
  }

  /// Checks for a pending join code stored before login redirect.
  ///
  /// Returns the join code if one was stored, null otherwise.
  /// Clears the stored code after retrieving it.
  static Future<String?> getAndClearPendingJoinCode() async {
    final code = await secureStorage.read(key: 'pending_join_code');
    if (code != null) {
      await secureStorage.delete(key: 'pending_join_code');
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
      final credential = await _readFirebaseAuthOrThrow()
          .createUserWithEmailAndPassword(email: email, password: password);
      // Create the users/{uid} doc up front so security rules (which read
      // accessRole) allow band create/join and other writes.
      await _ensureUserDocument(credential.user);
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
  /// To avoid account enumeration, a `user-not-found` result is treated as
  /// success (no error): the caller always shows the same neutral message.
  /// Genuine failures (network, rate-limit, invalid email) still throw
  /// [ApiError] so the user can act on them.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _readFirebaseAuthOrThrow().sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw _mapFirebaseAuthException(e);
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      throw apiError;
    }
  }

  /// Applies a targeted merge write to users/{uid}.
  ///
  /// The live [userDocProvider] snapshot then rebuilds AppUser on every
  /// screen (with Firestore latency compensation the UI updates immediately).
  /// Merge writes replace the old full-doc `saveUser` set(), which clobbered
  /// doc fields not present on a possibly-stale in-memory AppUser (#91).
  Future<void> _updateUserDoc(Map<String, Object?> fields) async {
    if (state.value == null) {
      throw ApiError.auth(message: 'No user logged in');
    }
    final user = _readFirebaseAuthOrThrow().currentUser;
    final firestore = _readFirestoreIfAvailable();
    if (user == null || firestore == null) {
      throw ApiError.auth(message: 'No user logged in');
    }

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .set(fields, SetOptions(merge: true));
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }
  }

  /// Updates the user's music roles.
  ///
  /// Throws [ApiError] if update fails.
  Future<void> updateMusicRoles(List<String> roles) async {
    await _updateUserDoc({'musicRoles': MusicRoleIcon.normalizeKeys(roles)});
  }

  /// Updates the user's profile photo URL.
  ///
  /// Throws [ApiError] if update fails.
  Future<void> updateProfilePhoto(String photoUrl) async {
    await _updateUserDoc({'photoURL': photoUrl});
  }

  /// Removes the user's profile photo.
  ///
  /// Throws [ApiError] if update fails.
  Future<void> removeProfilePhoto() async {
    await _updateUserDoc({'photoURL': null});
  }

  /// Updates the user's display name.
  ///
  /// Updates both Firebase Auth and Firestore.
  ///
  /// Throws [ApiError] if update fails.
  Future<void> updateDisplayName(String newName) async {
    if (state.value == null) {
      throw ApiError.auth(message: 'No user logged in');
    }

    try {
      final firebaseUser = _readFirebaseAuthOrThrow().currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(newName);
      }
    } catch (e, stackTrace) {
      final apiError = ApiError.fromException(e, stackTrace: stackTrace);
      state = AsyncValue.error(apiError, stackTrace);
      throw apiError;
    }

    await _updateUserDoc({'displayName': newName});
  }

  /// Maps Firebase Auth exceptions to ApiError with user-friendly messages.
  ApiError _mapFirebaseAuthException(FirebaseAuthException e) {
    final message = '${e.code} ${e.message ?? ''} $e'.toLowerCase();
    if (e.code == 'invalid-credential' ||
        e.code == 'invalid-login-credentials' ||
        message.contains('invalid credential') ||
        message.contains('invalid login') ||
        message.contains('invalid_login_credentials')) {
      return ApiError.auth(
        message: 'Incorrect password. Please try again.',
        exception: e,
      );
    }

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
