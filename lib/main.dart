import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint(
      'Note: .env file not loaded. Using environment variables if available.',
    );
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: RepSyncApp()));
}

class RepSyncApp extends ConsumerWidget {
  const RepSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state
    final userAsync = ref.watch(appUserProvider);

    // Set up auth state listener for navigation
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null && previous?.value == null) {
            // User just logged in - navigate to home
            GoRouter.of(context).goNamed('home');
          } else if (user == null && previous?.value != null) {
            // User just logged out - navigate to login
            GoRouter.of(context).goNamed('login');
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
          data: (user) => child ?? const SizedBox.shrink(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) {
            debugPrint('Auth error: $error');
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
