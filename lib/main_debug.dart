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
  debugPrint('🔍 [MAIN] Starting app initialization');

  // Initialize Hive for offline caching
  await Hive.initFlutter();
  debugPrint('🔍 [MAIN] Hive initialized');

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('🔍 [MAIN] .env file loaded');
  } catch (e) {
    debugPrint('🔍 [MAIN] Note: .env file not loaded. Using environment variables if available.');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔍 [MAIN] Firebase initialized');
  
  runApp(const ProviderScope(child: RepSyncAppDebug()));
}

class RepSyncAppDebug extends ConsumerWidget {
  const RepSyncAppDebug({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🔍 [MAIN] RepSyncAppDebug build() called');
    
    // Watch auth state
    final userAsync = ref.watch(appUserProvider);
    debugPrint('🔍 [MAIN] userAsync state: ${userAsync.isLoading ? 'LOADING' : userAsync.hasError ? 'ERROR' : 'DATA'}');

    // Set up auth state listener for navigation
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      debugPrint('🔍 [MAIN] auth state listener: previous=${previous?.value?.uid ?? 'NULL'}, next=${next.value?.uid ?? 'NULL'}');
      
      next.whenOrNull(
        data: (user) {
          debugPrint('🔍 [MAIN] auth listener data callback: user=${user?.uid ?? 'NULL'}');
          if (user != null && previous?.value == null) {
            // User just logged in - navigate to home
            debugPrint('🔍 [MAIN] 🔵 User just logged in, navigating to /main/home');
            context.go('/main/home');
          } else if (user == null && previous?.value != null) {
            // User just logged out - navigate to login
            debugPrint('🔍 [MAIN] 🔵 User just logged out, navigating to /login');
            context.go('/login');
          }
        },
        error: (error, stack) {
          debugPrint('🔍 [MAIN] auth listener error: $error');
          debugPrint('🔍 [MAIN] auth listener stack: $stack');
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
        debugPrint('🔍 [MAIN] builder() called, child=${child == null ? 'NULL' : 'PRESENT'}');
        
        return userAsync.when(
          data: (user) {
            debugPrint('🔍 [MAIN] builder data: user=${user?.uid ?? 'NULL'}');
            return child ?? const SizedBox.shrink();
          },
          loading: () {
            debugPrint('🔍 [MAIN] builder loading: showing CircularProgressIndicator');
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
          error: (error, stack) {
            debugPrint('🔍 [MAIN] builder error: $error');
            debugPrint('🔍 [MAIN] builder error stack: $stack');
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
