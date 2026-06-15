import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'theme/mono_pulse_theme.dart';
import 'providers/auth/auth_provider.dart';
import 'router/app_router.dart';
import 'models/user.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/config_error_widget.dart';
import 'utils/analytics_debug.dart';
import 'providers/metronome_runtime_providers.dart';
import 'services/analytics_service.dart';
import 'analytics/metronome_analytics.dart';
import 'config/config_validator.dart';
import 'repositories/metronome_session_repository.dart';
import 'services/metronome_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error widget for graceful degradation (prevents full red screen)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('⚠️ Widget error: ${details.exception}');
    debugPrint('   Stack: ${details.stack}');
    return Material(
      color: MonoPulseColors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: MonoPulseColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Something went wrong',
                style: MonoPulseTypography.headlineSmall.copyWith(
                  color: MonoPulseColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? details.exception.toString()
                    : 'Please restart the app or contact support.',
                style: MonoPulseTypography.bodySmall.copyWith(
                  color: MonoPulseColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Initialize Hive for offline caching
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(MetronomeSessionRepository.boxName);
  await Hive.openBox<dynamic>('metronome_presets_v1');
  MetronomeSessionRepository.storageReady = true;
  MetronomePreferences.storageReady = true;

  // Validate configuration BEFORE Firebase initialization
  // This ensures we have valid credentials before proceeding
  try {
    await ConfigValidator.validateOrThrow();
    debugPrint('✅ Configuration validated successfully');
  } on ConfigValidationException catch (e) {
    debugPrint('❌ Configuration validation failed: ${e.message}');
    // Run error app with validation error
    runApp(ConfigErrorApp(exception: e));
    return;
  }

  // Initialize Firebase with validated config
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    runApp(const FirebaseErrorApp());
    return;
  }

  // Initialize Firebase Analytics ONLY on mobile (not web)
  FirebaseAnalytics? analytics;
  if (!kIsWeb) {
    analytics = FirebaseAnalytics.instance;
    debugPrint('📊 Firebase Analytics initialized');

    // Initialize Analytics Service
    await AnalyticsService.initialize();

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
  } else {
    debugPrint('ℹ️  Web platform - skipping Analytics initialization');
  }

  // Enable Firebase Auth persistence for Android
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (_) {}

  // Suppress expected but non-critical Google Play Services errors in debug mode
  // These errors don't affect app functionality
  if (kDebugMode) {
    // GoogleApiManager DEVELOPER_ERROR is expected when:
    // - Debug build without proper SHA-1 fingerprint in Firebase console
    // - Emulator without Google Play Services fully configured
    // This doesn't block Firestore, Auth, or Analytics
    debugPrint('ℹ️  Note: Google Play Services errors in debug are expected');
    debugPrint('   They don\'t affect core app functionality');
  }

  final rootContainer = ProviderContainer();

  // Pre-initialize audio engine for instant first beat (deferred to avoid blocking startup)
  if (!kIsWeb) {
    // Defer audio initialization to after first frame
    // This prevents blocking the app startup and reduces initial jank
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stopwatch = Stopwatch()..start();
      Duration duration = Duration.zero;

      try {
        final audioClient = rootContainer.read(metronomeAudioClientProvider);
        await audioClient.initialize();
        await audioClient.preWarmPlayers();

        duration = stopwatch.elapsed;
        debugPrint('✅ Audio pre-initialized in ${duration.inMilliseconds}ms');

        // Log analytics
        await MetronomeAnalytics.logAudioInitialization(
          success: true,
          duration: duration,
        );
      } catch (e) {
        duration = stopwatch.elapsed;
        debugPrint('⚠️ Audio pre-initialization failed: $e');
        // Graceful degradation - will initialize on first use
        await MetronomeAnalytics.logAudioInitialization(
          success: false,
          duration: duration,
          error: e.toString(),
        );
      }
    });
  }

  // Check if user is already logged in (from previous session)
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    debugPrint(
      '🔑 AUTH RESTORED: User ${currentUser.email} found from previous session',
    );
    debugPrint('   UID: ${currentUser.uid}');
    debugPrint('   Email verified: ${currentUser.emailVerified}');

    // Log login event for existing user
    analytics?.logLogin(loginMethod: 'auto');
  } else {
    debugPrint('🔑 NO USER: No user found from previous session');
  }

  runApp(
    UncontrolledProviderScope(
      container: rootContainer,
      child: FlowGrooveApp(analytics: analytics),
    ),
  );
}

class FlowGrooveApp extends ConsumerWidget {
  final FirebaseAnalytics? analytics;

  FlowGrooveApp({super.key, this.analytics});

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
            // Use the global appRouter directly (not from context)
            appRouter.go('/main/home');
          } else if (user == null && previous?.value != null) {
            // User just logged out - navigate to login
            debugPrint('🔑 Auth Event: USER_LOGOUT - previous user logged out');
            appRouter.go('/login');
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

/// Error app displayed when configuration validation fails
class ConfigErrorApp extends StatelessWidget {
  final ConfigValidationException exception;

  const ConfigErrorApp({super.key, required this.exception});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuration Error',
      debugShowCheckedModeBanner: false,
      theme: MonoPulseTheme.theme,
      darkTheme: MonoPulseTheme.theme,
      themeMode: ThemeMode.dark,
      home: ConfigErrorWidget(
        exception: exception,
        onRetry: () {
          // Reload the app
          // Note: This is a simple reload - in production you might want more sophisticated handling
          debugPrint('Retry requested - reloading app');
        },
      ),
    );
  }
}

/// Error app displayed when Firebase initialization fails
class FirebaseErrorApp extends StatelessWidget {
  const FirebaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Error',
      debugShowCheckedModeBanner: false,
      theme: MonoPulseTheme.theme,
      darkTheme: MonoPulseTheme.theme,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Firebase Initialization Error',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The app could not connect to Firebase. '
                    'Please check your internet connection and try again.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
