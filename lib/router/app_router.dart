import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/song.dart';
import '../models/setlist.dart';
import '../models/band.dart';
import '../screens/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/songs/songs_list_screen.dart';
import '../screens/songs/add_song_screen.dart';
import '../screens/bands/my_bands_screen.dart';
import '../screens/bands/create_band_screen.dart';
import '../screens/bands/join_band_screen.dart';
import '../screens/bands/band_songs_screen.dart';
import '../screens/bands/band_about_screen.dart';
import '../screens/setlists/setlists_list_screen.dart';
import '../screens/setlists/create_setlist_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/metronome_screen.dart';
import '../screens/tuner_screen.dart';

/// Stream that notifies listeners when auth state changes.
/// Used to refresh GoRouter redirect logic.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Root navigator key for GoRouter.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration for RepSync.
///
/// Features:
/// - Type-safe navigation with path parameters
/// - Deep linking support via repSync:// scheme and https://repsync.app
/// - Nested routes for main app shell
/// - Auth state redirect on startup
///
/// Usage:
/// ```dart
/// // In widgets:
/// context.goSongs();
/// context.goEditSong(song);
/// ```
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isLoggingIn = state.matchedLocation == '/login';
    final isRegistering = state.matchedLocation == '/register';
    final isOnMain = state.matchedLocation.startsWith('/main');

    // Not logged in and not on auth pages -> go to login
    if (!isLoggedIn && !isLoggingIn && !isRegistering) {
      return '/login';
    }

    // Logged in and on auth pages -> go to main
    if (isLoggedIn && (isLoggingIn || isRegistering)) {
      return '/main/home';
    }

    // Logged in but on /main without child route -> go to home
    if (isLoggedIn && isOnMain && state.matchedLocation == '/main') {
      return '/main/home';
    }

    return null;
  },
  routes: [
    // Auth routes (public)
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
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Main app shell - using StatefulShellRoute.indexedStack for proper bottom nav
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        // Home branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/main/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Songs branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/main/songs',
              name: 'songs',
              builder: (context, state) => const SongsListScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'add-song',
                  builder: (context, state) {
                    final bandId = state.uri.queryParameters['bandId'];
                    return AddSongScreen(bandId: bandId);
                  },
                ),
                GoRoute(
                  path: ':id/edit',
                  name: 'edit-song',
                  builder: (context, state) {
                    final extra = state.extra;
                    Song? song;
                    String? bandId;
                    if (extra is Song) {
                      song = extra;
                    } else if (extra is Map) {
                      song = extra['song'] as Song?;
                      bandId = extra['bandId'] as String?;
                    }
                    return AddSongScreen(song: song, bandId: bandId);
                  },
                ),
              ],
            ),
          ],
        ),
        // Bands branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/main/bands',
              name: 'bands',
              builder: (context, state) => const MyBandsScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  name: 'create-band',
                  builder: (context, state) => const CreateBandScreen(),
                ),
                GoRoute(
                  path: ':id/edit',
                  name: 'edit-band',
                  builder: (context, state) {
                    final band = state.extra as Band?;
                    return CreateBandScreen(band: band);
                  },
                ),
                GoRoute(
                  path: ':id/songs',
                  name: 'band-songs',
                  builder: (context, state) {
                    final band = state.extra as Band?;
                    if (band == null) {
                      // Show error instead of infinite spinner
                      return Scaffold(
                        appBar: AppBar(title: const Text('Error')),
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Failed to load band data'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => context.pop(),
                                child: const Text('Go Back'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return BandSongsScreen(band: band);
                  },
                ),
                GoRoute(
                  path: ':id/about',
                  name: 'band-about',
                  builder: (context, state) {
                    final band = state.extra as Band?;
                    if (band == null) {
                      // Show error instead of infinite spinner
                      return Scaffold(
                        appBar: AppBar(title: const Text('Error')),
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Failed to load band data'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => context.pop(),
                                child: const Text('Go Back'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return BandAboutScreen(band: band);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/main/join-band',
              name: 'join-band',
              builder: (context, state) {
                final code = state.uri.queryParameters['code'];
                return JoinBandScreen(inviteCode: code);
              },
            ),
          ],
        ),
        // Setlists branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/main/setlists',
              name: 'setlists',
              builder: (context, state) => const SetlistsListScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  name: 'create-setlist',
                  builder: (context, state) => const CreateSetlistScreen(),
                ),
                GoRoute(
                  path: ':id/edit',
                  name: 'edit-setlist',
                  builder: (context, state) {
                    final setlist = state.extra as Setlist?;
                    return CreateSetlistScreen(setlist: setlist);
                  },
                ),
              ],
            ),
          ],
        ),
        // Profile branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/main/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        // Tools branch (not in bottom nav)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/main/metronome',
              name: 'metronome',
              builder: (context, state) => const MetronomeScreen(),
            ),
            GoRoute(
              path: '/main/tuner',
              name: 'tuner',
              builder: (context, state) => const TunerScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Extension on BuildContext for type-safe navigation.
///
/// Provides convenient methods for navigating to named routes
/// with proper type handling for path parameters and extra data.
extension GoRouterExtension on BuildContext {
  /// Navigate to home/dashboard.
  void goHome() => goNamed('home');

  /// Navigate to songs list.
  void goSongs() => goNamed('songs');

  /// Navigate to add song screen.
  void goAddSong({String? bandId}) {
    final Map<String, dynamic> params = bandId != null
        ? {'bandId': bandId}
        : {};
    goNamed('add-song', queryParameters: params);
  }

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

  /// Navigate to band about screen.
  void goBandAbout(Band band) =>
      goNamed('band-about', pathParameters: {'id': band.id}, extra: band);

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

  /// Navigate to tuner screen.
  void goTuner() => goNamed('tuner');

  /// Navigate to login screen.
  void goLogin() => goNamed('login');

  /// Navigate to register screen.
  void goRegister() => goNamed('register');

  /// Navigate to forgot password screen.
  void goForgotPassword() => goNamed('forgot-password');
}
