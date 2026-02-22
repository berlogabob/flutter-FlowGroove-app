import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'theme/mono_pulse_theme.dart';
import 'providers/auth/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_shell.dart';
import 'screens/songs/songs_list_screen.dart';
import 'screens/songs/add_song_screen.dart';
import 'screens/bands/my_bands_screen.dart';
import 'screens/bands/create_band_screen.dart';
import 'screens/bands/join_band_screen.dart';
import 'screens/bands/band_songs_screen.dart';
import 'screens/setlists/setlists_list_screen.dart';
import 'screens/setlists/create_setlist_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/metronome_screen.dart';
import 'models/song.dart';
import 'models/setlist.dart';
import 'models/band.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline caching
  await Hive.initFlutter();

  // Load environment variables
  // For web, .env file is optional - use default values if not found
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // For web development, environment variables can be set via other means
    // This allows the app to run even if .env file is not present
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

    return MaterialApp(
      title: 'RepSync',
      debugShowCheckedModeBanner: false,
      theme: MonoPulseTheme.theme,
      darkTheme: MonoPulseTheme.theme,
      themeMode: ThemeMode.dark, // Dark-only as per brandbook
      // Show splash screen while checking auth
      home: userAsync.when(
        data: (user) => user != null ? const MainShell() : const LoginScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => const LoginScreen(),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainShell(),
        '/songs': (context) => const SongsListScreen(),
        '/songs/add': (context) => const AddSongScreen(),
        '/bands': (context) => const MyBandsScreen(),
        '/bands/create': (context) => const CreateBandScreen(),
        '/bands/join': (context) => const JoinBandScreen(),
        '/setlists': (context) => const SetlistsListScreen(),
        '/setlists/create': (context) => const CreateSetlistScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/metronome': (context) => const MetronomeScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes with arguments
        final uri = Uri.parse(settings.name ?? '');

        // Edit song route: /songs/:id/edit
        if (uri.pathSegments.length == 3 &&
            uri.pathSegments[0] == 'songs' &&
            uri.pathSegments[2] == 'edit') {
          final song = settings.arguments as Song?;
          return MaterialPageRoute(builder: (_) => AddSongScreen(song: song));
        }

        // Edit band route: /bands/:id/edit
        if (uri.pathSegments.length == 3 &&
            uri.pathSegments[0] == 'bands' &&
            uri.pathSegments[2] == 'edit') {
          final band = settings.arguments as Band?;
          return MaterialPageRoute(
            builder: (_) => CreateBandScreen(band: band),
          );
        }

        // Edit setlist route: /setlists/:id/edit
        if (uri.pathSegments.length == 3 &&
            uri.pathSegments[0] == 'setlists' &&
            uri.pathSegments[2] == 'edit') {
          final setlist = settings.arguments as Setlist?;
          return MaterialPageRoute(
            builder: (_) => CreateSetlistScreen(setlist: setlist),
          );
        }

        // Band songs route: /bands/:id/songs
        if (uri.pathSegments.length == 3 &&
            uri.pathSegments[0] == 'bands' &&
            uri.pathSegments[2] == 'songs') {
          final band = settings.arguments as Band?;
          if (band == null) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return MaterialPageRoute(builder: (_) => BandSongsScreen(band: band));
        }

        return null;
      },
    );
  }
}
