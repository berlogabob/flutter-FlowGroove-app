import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'theme/mono_pulse_theme.dart';
import 'providers/auth/auth_provider.dart';
import 'router/app_router.dart';
import 'models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline caching
  await Hive.initFlutter();

  // Load environment variables ONLY if file exists (development only)
  // In production, Firebase credentials are hardcoded in firebase_options.dart
  if (!kIsWeb) {
    // Only try to load .env on mobile/desktop (not web)
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // Silently ignore - production builds don't have .env
    }
  }
  // On web, skip .env loading entirely - use hardcoded Firebase config

  // Initialize Firebase first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized');

  // Enable Firebase Auth persistence for Android ONLY (not web)
  if (!kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      debugPrint('✅ Auth persistence set to LOCAL');
    } catch (e) {
      debugPrint('⚠️  Auth persistence failed: $e');
    }
  } else {
    debugPrint('ℹ️  Web platform - using default auth persistence');
  }

  // Check if user is already logged in (from previous session)
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    debugPrint(
      '🔑 AUTH RESTORED: User ${currentUser.email} found from previous session',
    );
    debugPrint('   UID: ${currentUser.uid}');
    debugPrint('   Email verified: ${currentUser.emailVerified}');
  } else {
    debugPrint('🔑 NO USER: No user found from previous session');
  }

  runApp(const ProviderScope(child: RepSyncApp()));
}

class RepSyncApp extends ConsumerWidget {
  const RepSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state
    final userAsync = ref.watch(appUserProvider);

    // Set up auth state listener for navigation with logging
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null && previous?.value == null) {
            // User just logged in - navigate to home
            debugPrint('🔑 Auth Event: USER_LOGIN - email=${user.email}');
            GoRouter.of(context).go('/main/home');
          } else if (user == null && previous?.value != null) {
            // User just logged out - navigate to login
            debugPrint('🔑 Auth Event: USER_LOGOUT - previous user logged out');
            GoRouter.of(context).go('/login');
          } else if (user != null) {
            // Auth state restored (app resume/refresh)
            debugPrint('🔑 Auth Event: AUTH_RESTORED - email=${user.email}');
          }
        },
      );
    });

    return MaterialApp.router(
      title: 'RepSync',
      debugShowCheckedModeBanner: false,
      theme: MonoPulseTheme.theme,
      darkTheme: MonoPulseTheme.theme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        // Handle loading state
        // Note: child can be null during initial route resolution
        return userAsync.when(
          data: (user) {
            debugPrint('🟢 Auth state: DATA - user=${user?.email ?? "NULL"}');
            return child ?? const SizedBox.shrink();
          },
          loading: () {
            debugPrint('🟡 Auth state: LOADING');
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
          error: (error, stack) {
            debugPrint('🔴 Auth state: ERROR - $error');
            debugPrint('Stack: $stack');
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
