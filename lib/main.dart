import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/songs/songs_list_screen.dart';
import 'screens/songs/add_song_screen.dart';
import 'screens/bands/my_bands_screen.dart';
import 'screens/bands/create_band_screen.dart';
import 'screens/bands/join_band_screen.dart';
import 'screens/setlists/setlists_list_screen.dart';
import 'screens/setlists/create_setlist_screen.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: RepSyncApp()));
}

class RepSyncApp extends ConsumerWidget {
  const RepSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'RepSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const LoginScreen(),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/songs': (context) => const SongsListScreen(),
        '/add-song': (context) => const AddSongScreen(),
        '/bands': (context) => const MyBandsScreen(),
        '/create-band': (context) => const CreateBandScreen(),
        '/join-band': (context) => const JoinBandScreen(),
        '/setlists': (context) => const SetlistsListScreen(),
        '/create-setlist': (context) => const CreateSetlistScreen(),
      },
    );
  }
}
