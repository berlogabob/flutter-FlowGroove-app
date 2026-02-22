import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/song.dart';
import '../models/setlist.dart';
import '../models/band.dart';
import '../screens/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/songs/songs_list_screen.dart';
import '../screens/songs/add_song_screen.dart';
import '../screens/bands/my_bands_screen.dart';
import '../screens/bands/create_band_screen.dart';
import '../screens/bands/join_band_screen.dart';
import '../screens/bands/band_songs_screen.dart';
import '../screens/setlists/setlists_list_screen.dart';
import '../screens/setlists/create_setlist_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/metronome_screen.dart';

/// GoRouter configuration for type-safe navigation.
///
/// All routes are defined here with support for:
/// - Type-safe path parameters
/// - Deep linking
/// - Nested routes
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Root route - shows home or login based on auth state
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // Auth routes
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Main shell (authenticated navigation)
    GoRoute(
      path: '/main',
      name: 'main',
      builder: (context, state) => const MainShell(),
    ),

    // Songs routes
    GoRoute(
      path: '/songs',
      name: 'songs',
      builder: (context, state) => const SongsListScreen(),
    ),
    GoRoute(
      path: '/songs/add',
      name: 'add-song',
      builder: (context, state) => const AddSongScreen(),
    ),
    GoRoute(
      path: '/songs/:id/edit',
      name: 'edit-song',
      builder: (context, state) {
        final song = state.extra as Song?;
        return AddSongScreen(song: song);
      },
    ),

    // Bands routes
    GoRoute(
      path: '/bands',
      name: 'bands',
      builder: (context, state) => const MyBandsScreen(),
    ),
    GoRoute(
      path: '/bands/create',
      name: 'create-band',
      builder: (context, state) => const CreateBandScreen(),
    ),
    GoRoute(
      path: '/bands/:id/edit',
      name: 'edit-band',
      builder: (context, state) {
        final band = state.extra as Band?;
        return CreateBandScreen(band: band);
      },
    ),
    GoRoute(
      path: '/bands/join',
      name: 'join-band',
      builder: (context, state) => const JoinBandScreen(),
    ),
    GoRoute(
      path: '/bands/:id/songs',
      name: 'band-songs',
      builder: (context, state) {
        final band = state.extra as Band?;
        if (band == null) {
          // If no band provided, navigate back to bands list
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/bands');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return BandSongsScreen(band: band);
      },
    ),

    // Setlists routes
    GoRoute(
      path: '/setlists',
      name: 'setlists',
      builder: (context, state) => const SetlistsListScreen(),
    ),
    GoRoute(
      path: '/setlists/create',
      name: 'create-setlist',
      builder: (context, state) => const CreateSetlistScreen(),
    ),
    GoRoute(
      path: '/setlists/:id/edit',
      name: 'edit-setlist',
      builder: (context, state) {
        final setlist = state.extra as Setlist?;
        return CreateSetlistScreen(setlist: setlist);
      },
    ),

    // Profile route
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),

    // Metronome route
    GoRoute(
      path: '/metronome',
      name: 'metronome',
      builder: (context, state) => const MetronomeScreen(),
    ),
  ],
);

/// Extension on BuildContext for type-safe navigation.
///
/// Provides convenient methods for navigating to named routes
/// with proper type handling for path parameters and extra data.
extension GoRouterExtension on BuildContext {
  /// Navigate to songs list.
  void goSongs() => goNamed('songs');

  /// Navigate to add song screen.
  void goAddSong() => goNamed('add-song');

  /// Navigate to edit song screen.
  void goEditSong(Song song) =>
      goNamed('edit-song', pathParameters: {'id': song.id}, extra: song);

  /// Navigate to bands list.
  void goBands() => goNamed('bands');

  /// Navigate to create band screen.
  void goCreateBand() => goNamed('create-band');

  /// Navigate to edit band screen.
  void goEditBand(Band band) =>
      goNamed('edit-band', pathParameters: {'id': band.id}, extra: band);

  /// Navigate to join band screen.
  void goJoinBand() => goNamed('join-band');

  /// Navigate to band songs screen.
  void goBandSongs(Band band) =>
      goNamed('band-songs', pathParameters: {'id': band.id}, extra: band);

  /// Navigate to setlists list.
  void goSetlists() => goNamed('setlists');

  /// Navigate to create setlist screen.
  void goCreateSetlist() => goNamed('create-setlist');

  /// Navigate to edit setlist screen.
  void goEditSetlist(Setlist setlist) => goNamed(
    'edit-setlist',
    pathParameters: {'id': setlist.id},
    extra: setlist,
  );

  /// Navigate to profile screen.
  void goProfile() => goNamed('profile');

  /// Navigate to metronome screen.
  void goMetronome() => goNamed('metronome');

  /// Navigate to login screen.
  void goLogin() => goNamed('login');

  /// Navigate to register screen.
  void goRegister() => goNamed('register');

  /// Navigate to main shell.
  void goMain() => goNamed('main');
}
