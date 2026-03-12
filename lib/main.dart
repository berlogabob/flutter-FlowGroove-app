import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'theme/mono_pulse_theme.dart';
import 'providers/auth/auth_provider.dart';
import 'router/app_router.dart';
import 'models/user.dart';
import 'widgets/loading_indicator.dart';
import 'utils/analytics_debug.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline caching
  await Hive.initFlutter();

  // Load environment variables
  try {
    await dotenv.load(fileName: 'assets/env.json');
  } catch (e) {
    debugPrint(
      'Note: .env file not loaded. Using environment variables if available.',
    );
  }

  // Initialize Firebase first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized');

  // Initialize Firebase Analytics
  final analytics = FirebaseAnalytics.instance;
  debugPrint('📊 Firebase Analytics initialized');

  // Enable analytics collection (explicitly)
  await analytics.setAnalyticsCollectionEnabled(true);
  debugPrint('📊 Analytics collection enabled');
  
  // Enable debug mode for development
  AnalyticsDebug.enableDebugMode();
  
  // Test analytics connection
  AnalyticsDebug.testConnection();

  // Log app open event
  AnalyticsDebug.logAppOpen();
  debugPrint('📊 App open event logged');

  // Enable Firebase Auth persistence for Android
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (_) {}

  // Check if user is already logged in (from previous session)
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    debugPrint(
      '🔑 AUTH RESTORED: User ${currentUser.email} found from previous session',
    );
    debugPrint('   UID: ${currentUser.uid}');
    debugPrint('   Email verified: ${currentUser.emailVerified}');
    
    // Log login event for existing user
    analytics.logLogin(loginMethod: 'auto');
  } else {
    debugPrint('🔑 NO USER: No user found from previous session');
  }

  runApp(ProviderScope(child: RepSyncApp(analytics: analytics)));
}

class RepSyncApp extends ConsumerWidget {
  final FirebaseAnalytics analytics;

  RepSyncApp({super.key, required this.analytics});

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
      title: 'FlowGroove',
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
            return const Scaffold(body: Center(child: LoadingIndicator()));
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
