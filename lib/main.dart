import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'analytics/metronome_analytics.dart';
import 'config/config_validator.dart';
import 'firebase_options.dart';
import 'models/user.dart';
import 'providers/analytics_consent_provider.dart';
import 'providers/auth/auth_provider.dart';
import 'providers/keep_screen_on_provider.dart';
import 'providers/metronome_runtime_providers.dart';
import 'repositories/metronome_session_repository.dart';
import 'router/app_router.dart';
import 'services/analytics_service.dart';
import 'services/metronome_preferences.dart';
import 'theme/mono_pulse_theme.dart';
import 'utils/analytics_debug.dart';
import 'utils/responsive_breakpoints.dart';
import 'widgets/config_error_widget.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/wiki_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // debugPrint still emits in release builds; silence the app's ~250 log
  // call sites globally instead of guarding each one.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Global error widget for graceful degradation (prevents full red screen)
  ErrorWidget.builder = (details) {
    debugPrint('⚠️ Widget error: ${details.exception}');
    debugPrint('   Stack: ${details.stack}');
    return Material(
      color: MonoPulseColors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
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

  // Initialize Firebase with validated config.
  //
  // On Android/iOS the native FirebaseInitProvider already auto-initializes the
  // [DEFAULT] app from google-services.json / GoogleService-Info.plist before
  // Dart runs. Calling initializeApp again with options whose values differ from
  // that bundled config (e.g. a dart-defined FIREBASE_API_KEY that doesn't match
  // the key in google-services.json) throws [core/duplicate-app]. When a default
  // app already exists we reuse it — on mobile the native config is the source of
  // truth. Only initialize explicitly when no app exists yet (e.g. web).
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('✅ Firebase initialized');
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // Native auto-init already created [DEFAULT]; safe to continue.
      debugPrint('ℹ️  Firebase already initialized natively; reusing [DEFAULT]');
    } else {
      debugPrint('❌ Firebase initialization failed: $e');
      runApp(const FirebaseErrorApp());
      return;
    }
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    runApp(const FirebaseErrorApp());
    return;
  }

  // Firebase Analytics (mobile only). Grab the singleton now (cheap) but defer
  // the awaited init/collection/connection/app-open work to after the first
  // frame so it never blocks startup. Events logged before the deferred enable
  // are buffered by Firebase Analytics.
  FirebaseAnalytics? analytics;
  if (!kIsWeb) {
    analytics = FirebaseAnalytics.instance;
    AnalyticsDebug.enableDebugMode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AnalyticsService.initialize();
        await analytics!.setAnalyticsCollectionEnabled(true);
        await AnalyticsDebug.testConnection();
        await AnalyticsDebug.logAppOpen();
        debugPrint('📊 Analytics initialized (deferred, off critical path)');
      } catch (e) {
        debugPrint('⚠️ Deferred analytics init failed: $e');
      }
    });
  } else {
    debugPrint('ℹ️  Web platform - skipping Analytics initialization');
  }

  // Enable Firestore offline persistence on every platform (mobile has it on
  // by default, web does not). This replaces the removed Hive data cache:
  // first paint comes from the SDK's disk cache and self-corrects live (#91).
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (_) {}

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
    debugPrint("   They don't affect core app functionality");
  }

  final rootContainer = ProviderContainer();

  // Apply the global "keep screen on" preference (default on). Reading the
  // provider constructs the notifier, which loads the stored value and applies
  // the wakelock — providers are lazy, so it must be read once at startup.
  rootContainer.read(keepScreenOnProvider);

  // Apply the global "share usage analytics" preference (default on). Same
  // lazy-provider-construction pattern as keepScreenOnProvider above.
  rootContainer.read(analyticsConsentProvider);

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

    // Log login event for existing user (off the startup critical path)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      analytics?.logLogin(loginMethod: 'auto');
    });
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
  const FlowGrooveApp({super.key, this.analytics});

  final FirebaseAnalytics? analytics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state
    final userAsync = ref.watch(appUserProvider);

    // Set up auth state listener for navigation with logging
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      // Log-only: navigation is owned by the router redirect (refreshListenable
      // re-runs on every authStateChanges) and the login/register screens. This
      // listener must NOT call appRouter.go(...) — doing so on cold-start auth
      // restore raced and clobbered the /join deep-link redirect, dumping users
      // on Home instead of the Join Band screen.
      next.whenOrNull(
        data: (user) {
          if (user != null && previous?.value == null) {
            debugPrint('🔑 Auth Event: USER_LOGIN - email=${user.email}');
          } else if (user == null && previous?.value != null) {
            debugPrint('🔑 Auth Event: USER_LOGOUT - previous user logged out');
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
            return _withDesktopWiki(context, child ?? const SizedBox.shrink());
          },
          loading: () {
            debugPrint('🟡 Auth state: LOADING');
            return const Scaffold(body: Center(child: LoadingIndicator()));
          },
          error: (error, stack) {
            debugPrint('🔴 Auth state: ERROR - $error');
            debugPrint('Stack: $stack');
            return _withDesktopWiki(context, child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}

/// On desktop, render the app in a fixed 480px phone-width column with the
/// wiki panel on the right. `app` is the root navigator (the builder's
/// `child`), so all its dialogs/menus/overlays stay inside the left column.
Widget _withDesktopWiki(BuildContext context, Widget app) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (getBreakpoint(constraints.maxWidth) != ScreenBreakpoint.desktop) {
        return app;
      }
      final mq = MediaQuery.of(context);
      return Row(
        children: [
          SizedBox(
            width: 480,
            child: MediaQuery(
              data: mq.copyWith(size: Size(480, mq.size.height)),
              child: app,
            ),
          ),
          Container(width: 1, color: MonoPulseColors.borderSubtle),
          const Expanded(child: WikiPanel()),
        ],
      );
    },
  );
}

/// Error app displayed when configuration validation fails
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.exception, super.key});

  final ConfigValidationException exception;

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
              padding: const EdgeInsets.all(24),
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
