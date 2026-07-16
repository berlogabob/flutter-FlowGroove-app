import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/band.dart';
import '../models/rehearsal.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../models/tuner_launch_context.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/data/data_providers.dart';
import '../services/analytics_service.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/bands/band_about_screen.dart';
import '../screens/bands/band_invite_screen.dart';
import '../screens/bands/band_members_screen.dart';
import '../screens/bands/band_setlists_screen.dart';
import '../screens/bands/band_songs_screen.dart';
import '../screens/bands/create_band_screen.dart';
import '../screens/bands/join_band_screen.dart';
import '../screens/bands/my_bands_screen.dart';
import '../screens/bands/rehearsals/rehearsal_detail_screen.dart';
import '../screens/bands/rehearsals/rehearsal_edit_screen.dart';
import '../screens/bands/rehearsals/rehearsals_list_screen.dart';
import '../screens/bands/the_band_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/metronome_screen.dart';
import '../screens/practice_placeholder_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/setlists/create_setlist_screen.dart';
import '../screens/setlists/setlist_view_screen.dart';
import '../screens/setlists/setlists_list_screen.dart';
import '../screens/songs/add_song_screen.dart';
import '../screens/songs/canonical_browse_screen.dart';
import '../screens/songs/models/song_form_data.dart';
import '../screens/songs/song_duplicates_screen.dart';
import '../screens/songs/songs_list_screen.dart';
import '../screens/tuner_screen.dart';
import 'branch_stack_observer.dart';

/// Minimal auth surface needed by the app router.
abstract class AuthRouterClient {
  Stream<User?> authStateChanges();

  User? get currentUser;
}

/// Production auth adapter for GoRouter redirects.
class FirebaseAuthRouterClient implements AuthRouterClient {
  FirebaseAuthRouterClient([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;
}

/// Refresh listenable for the router that also tracks whether the first auth
/// state has arrived.
///
/// On cold start Firebase Auth reports `currentUser == null` until it restores
/// the persisted session. [resolved] lets the redirect avoid making a
/// logged-out decision during that gap — which otherwise sends an
/// already-authenticated user to /login and orphans an incoming join deep link.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(AuthRouterClient client) {
    resolved = client.currentUser != null;
    _subscription = client.authStateChanges().listen((_) {
      resolved = true;
      notifyListeners();
    });
  }

  bool resolved = false;
  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Root navigator key for GoRouter.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Production GoRouter configuration for FlowGroove.
final GoRouter appRouter = createAppRouter();

/// Creates a GoRouter with injectable auth and route configuration.
GoRouter createAppRouter({
  AuthRouterClient? authClient,
  String initialLocation = '/login',
  GlobalKey<NavigatorState>? navigatorKey,
  List<RouteBase>? routes,
  bool enableAuthRedirect = true,
}) {
  final resolvedAuthClient = authClient ?? FirebaseAuthRouterClient();
  final authRefresh = enableAuthRedirect
      ? GoRouterRefreshStream(resolvedAuthClient)
      : null;

  return GoRouter(
    navigatorKey: navigatorKey ?? _rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: authRefresh,
    redirect: enableAuthRedirect
        ? (context, state) {
            final isLoggedIn = resolvedAuthClient.currentUser != null;
            final isLoggingIn = state.matchedLocation == '/login';
            final isRegistering = state.matchedLocation == '/register';
            final isOnMain = state.matchedLocation.startsWith('/main');
            final joinCode = state.uri.queryParameters['code'];

            // External join App Link / web deep link (/join or /join/) — map it
            // to the in-app join flow. When logged out, stash the code so login
            // can resume the join.
            final isExternalJoin =
                state.matchedLocation == '/join' ||
                state.matchedLocation == '/join/';
            if (isExternalJoin) {
              // On cold start Firebase Auth has not restored the session yet, so
              // currentUser is briefly null. Deciding now would treat an
              // authenticated user as logged out and orphan the join. Hold on the
              // /join spinner until the first auth state is known — the
              // refreshListenable re-runs this redirect once it is.
              if (authRefresh != null && !authRefresh.resolved) return null;
              AnalyticsService.logInviteLinkOpened();
              if (joinCode == null || joinCode.isEmpty) {
                return isLoggedIn ? '/main/bands' : '/login';
              }
              if (isLoggedIn) {
                return '/main/join-band?code=$joinCode';
              }
              unawaited(PendingJoinCodeStore().setPendingJoinCode(joinCode));
              return '/login';
            }

            // Not logged in and not on auth pages -> go to login.
            // If a join link (with ?code=) was opened while logged out, stash
            // the code so the login flow can resume the join afterwards.
            if (!isLoggedIn && !isLoggingIn && !isRegistering) {
              if (state.matchedLocation == '/main/join-band' &&
                  joinCode != null &&
                  joinCode.isNotEmpty) {
                unawaited(PendingJoinCodeStore().setPendingJoinCode(joinCode));
              }
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
          }
        : null,
    routes: routes ?? _buildAppRoutes(),
  );
}

/// GoRouter routes for FlowGroove.
///
/// Features:
/// - Type-safe navigation with path parameters
/// - Deep linking support via flowgroove:// scheme and https://flowgroove.app
/// - Nested routes for main app shell
/// - Auth state redirect on startup
///
/// Usage:
/// ```dart
/// // In widgets:
/// context.goSongs();
/// context.goEditSong(song);
/// ```
List<RouteBase> _buildAppRoutes() {
  return [
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
    // External join deep link target (App Link / web). The global redirect
    // always routes this onward (to join-band or login), so this builder is
    // only a brief placeholder.
    GoRoute(
      path: '/join',
      name: 'join-deeplink',
      builder: (context, state) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),

    // Main app shell - using StatefulShellRoute.indexedStack for proper bottom nav
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        // Home branch
        StatefulShellBranch(
          observers: [BranchStackObserver(0)],
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
          observers: [BranchStackObserver(1)],
          routes: [
            GoRoute(
              path: '/main/songs',
              name: 'songs',
              builder: (context, state) => const SongsListScreen(),
              routes: [
                GoRoute(
                  path: 'duplicates',
                  name: 'song-duplicates',
                  builder: (context, state) => const SongDuplicatesScreen(),
                ),
                GoRoute(
                  path: 'catalog',
                  name: 'canonical-browse',
                  builder: (context, state) => const CanonicalBrowseScreen(),
                ),
                GoRoute(
                  path: 'add',
                  name: 'add-song',
                  builder: (context, state) {
                    final bandId = state.uri.queryParameters['bandId'];
                    return AddSongScreen(
                      bandId: bandId,
                      initialFormData: state.extra is SongFormData
                          ? state.extra! as SongFormData
                          : null,
                    );
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
          observers: [BranchStackObserver(2)],
          routes: [
            GoRoute(
              path: '/main/bands',
              name: 'bands',
              builder: (context, state) => const MyBandsScreen(),
              routes: [
                // NOTE: the literal 'create' route MUST be declared before the
                // parameterized ':id' route. go_router matches child routes in
                // declaration order, so if ':id' came first it would greedily
                // match '/main/bands/create' as a band with id="create" and
                // show "Failed to load band data" instead of the create screen.
                GoRoute(
                  path: 'create',
                  name: 'create-band',
                  builder: (context, state) => const CreateBandScreen(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'the-band',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => TheBandScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/edit',
                  name: 'edit-band',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => CreateBandScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/songs',
                  name: 'band-songs',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => BandSongsScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/setlists',
                  name: 'band-setlists',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => BandSetlistsScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/about',
                  name: 'band-about',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => BandAboutScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/invite',
                  name: 'band-invite',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => BandInviteScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/members',
                  name: 'band-members',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => BandMembersScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/rehearsals',
                  name: 'band-rehearsals',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => RehearsalsListScreen(band: band),
                  ),
                ),
                // 'create' before ':rid' so it isn't matched as rid="create".
                GoRoute(
                  path: ':id/rehearsals/create',
                  name: 'create-rehearsal',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    extra: state.extra as Band?,
                    builder: (band) => RehearsalEditScreen(band: band),
                  ),
                ),
                GoRoute(
                  path: ':id/rehearsals/:rid/edit',
                  name: 'edit-rehearsal',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    builder: (band) => RehearsalEditScreen(
                      band: band,
                      rehearsal: state.extra as Rehearsal?,
                    ),
                  ),
                ),
                GoRoute(
                  path: ':id/rehearsals/:rid',
                  name: 'rehearsal-detail',
                  builder: (context, state) => BandRouteResolver(
                    bandId: state.pathParameters['id'],
                    builder: (band) => RehearsalDetailScreen(
                      band: band,
                      rehearsalId: state.pathParameters['rid']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Setlists branch
        StatefulShellBranch(
          observers: [BranchStackObserver(3)],
          routes: [
            GoRoute(
              path: '/main/setlists',
              name: 'setlists',
              builder: (context, state) => const SetlistsListScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  name: 'create-setlist',
                  builder: (context, state) {
                    final bandId = state.uri.queryParameters['bandId'];
                    final scope =
                        state.uri.queryParameters['scope'] ==
                            SetlistStorageScope.band.name
                        ? SetlistStorageScope.band
                        : SetlistStorageScope.personal;
                    return CreateSetlistScreen(
                      bandId: bandId,
                      storageScope: scope,
                    );
                  },
                ),
                // 'create' is declared above the parameterized ':id' route
                // for the same reason as the bands branch: go_router matches
                // child routes in declaration order, so ':id' first would
                // greedily match '/main/setlists/create' as a setlist with
                // id="create".
                GoRoute(
                  path: ':id',
                  name: 'setlist-view',
                  builder: (context, state) {
                    final setlist = state.extra as Setlist?;
                    final scope =
                        state.uri.queryParameters['scope'] ==
                            SetlistStorageScope.band.name
                        ? SetlistStorageScope.band
                        : SetlistStorageScope.personal;
                    final bandId = state.uri.queryParameters['bandId'];
                    return SetlistRouteResolver(
                      setlistId: state.pathParameters['id'],
                      bandId: bandId,
                      extra: setlist,
                      builder: (live) => SetlistViewScreen(
                        setlist: live,
                        bandId: bandId,
                        storageScope: scope,
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: ':id/edit',
                  name: 'edit-setlist',
                  builder: (context, state) {
                    final setlist = state.extra as Setlist?;
                    final scope =
                        state.uri.queryParameters['scope'] ==
                            SetlistStorageScope.band.name
                        ? SetlistStorageScope.band
                        : SetlistStorageScope.personal;
                    final bandId = state.uri.queryParameters['bandId'];
                    return SetlistRouteResolver(
                      setlistId: state.pathParameters['id'],
                      bandId: bandId,
                      extra: setlist,
                      builder: (live) => CreateSetlistScreen(
                        setlist: live,
                        bandId: bandId,
                        storageScope: scope,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // Profile branch
        StatefulShellBranch(
          observers: [BranchStackObserver(4)],
          routes: [
            GoRoute(
              path: '/main/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Tool screens and Join Band are pushed on top of the
    // shell via the root navigator instead of living in a shell branch. That
    // way there's always a shell screen underneath to pop back to, so system
    // back (and the app bar back arrow) return to the app instead of exiting
    // it. Names/paths are unchanged so the deep-link redirect below (which
    // returns '/main/join-band?code=...' as a location string) still resolves.
    GoRoute(
      path: '/main/metronome',
      name: 'metronome',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        AnalyticsService.logToolOpened(tool: 'metronome');
        return const MetronomeScreen();
      },
    ),
    GoRoute(
      path: '/main/practice',
      name: 'practice',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        AnalyticsService.logToolOpened(tool: 'practice');
        return const PracticePlaceholderScreen();
      },
    ),
    GoRoute(
      path: '/main/tuner',
      name: 'tuner',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        AnalyticsService.logToolOpened(tool: 'tuner');
        return TunerScreen(
          launchContext: state.extra is TunerLaunchContext
              ? state.extra! as TunerLaunchContext
              : null,
        );
      },
    ),
    GoRoute(
      path: '/main/join-band',
      name: 'join-band',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return JoinBandScreen(inviteCode: code);
      },
    ),
  ];
}

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
  void goAddSong({String? bandId, SongFormData? initialFormData}) {
    final Map<String, dynamic> params = bandId != null
        ? {'bandId': bandId}
        : {};
    goNamed('add-song', queryParameters: params, extra: initialFormData);
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

  /// Navigate to the band screen (band details page).
  void goTheBand(Band band) =>
      goNamed('the-band', pathParameters: {'id': band.id}, extra: band);

  /// Navigate to join band screen. Pushed on the root navigator (see
  /// [_buildAppRoutes]) so back returns to whatever screen is underneath
  /// instead of exiting the app.
  void goJoinBand() => pushNamed('join-band');

  /// Navigate to band songs screen.
  void goBandSongs(Band band) =>
      goNamed('band-songs', pathParameters: {'id': band.id}, extra: band);

  /// Navigate to band setlists screen.
  void goBandSetlists(Band band) =>
      goNamed('band-setlists', pathParameters: {'id': band.id}, extra: band);

  /// Navigate to band about screen.
  void goBandAbout(Band band) =>
      goNamed('band-about', pathParameters: {'id': band.id}, extra: band);

  /// Navigate to setlists list.
  void goSetlists() => goNamed('setlists');

  /// Navigate to create setlist screen.
  void goCreateSetlist({
    String? bandId,
    SetlistStorageScope storageScope = SetlistStorageScope.personal,
  }) {
    final Map<String, dynamic> params = {};
    if (bandId != null) params['bandId'] = bandId;
    if (storageScope == SetlistStorageScope.band) {
      params['scope'] = SetlistStorageScope.band.name;
    }
    goNamed('create-setlist', queryParameters: params);
  }

  /// Navigate to create shared band setlist screen.
  void goCreateBandSetlist(Band band) {
    goCreateSetlist(bandId: band.id, storageScope: SetlistStorageScope.band);
  }

  /// Navigate to edit setlist screen.
  void goEditSetlist(Setlist setlist) => goNamed(
    'edit-setlist',
    pathParameters: {'id': setlist.id},
    extra: setlist,
  );

  /// Navigate to profile screen.
  void goProfile() => goNamed('profile');

  /// Navigate to metronome screen. Pushed on the root navigator (see
  /// [_buildAppRoutes]) so back returns to whatever screen is underneath
  /// instead of exiting the app.
  void goMetronome() => pushNamed('metronome');

  /// Navigate to tuner screen. Pushed on the root navigator (see
  /// [_buildAppRoutes]) so back returns to whatever screen is underneath
  /// instead of exiting the app.
  void goTuner({TunerLaunchContext? launchContext}) =>
      pushNamed('tuner', extra: launchContext);

  /// Navigate to login screen.
  void goLogin() => goNamed('login');

  /// Navigate to register screen.
  void goRegister() => goNamed('register');

  /// Navigate to forgot password screen.
  void goForgotPassword() => goNamed('forgot-password');
}

/// Resolves the [Band] for band detail routes.
///
/// go_router does NOT persist `state.extra` across app restarts or deep links,
/// so a band route opened by route restoration (e.g. after an app update) has a
/// null Band and previously showed "Failed to load band data". This widget
/// falls back to looking the band up by its id from the user's loaded bands.
class BandRouteResolver extends ConsumerWidget {
  const BandRouteResolver({
    required this.bandId,
    required this.builder,
    this.extra,
    super.key,
  });

  final String? bandId;
  final Band? extra;
  final Widget Function(Band band) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the live band from the stream so edits made elsewhere (name, tags,
    // description, member roles) show up without re-navigating. `extra` is only a
    // navigation-time snapshot, used as a fallback while the stream loads or if
    // the band isn't in the list yet.
    final bands = ref.watch(bandsProvider).asData?.value;
    if (bands != null) {
      for (final candidate in bands) {
        if (candidate.id == bandId) return builder(candidate);
      }
      if (extra != null) return builder(extra!);
      return _bandLoadError(context);
    }

    if (extra != null) return builder(extra!);
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _bandLoadError(BuildContext context) {
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
}

/// Resolves the [Setlist] for the setlist-view and edit-setlist routes.
///
/// Same rationale as [BandRouteResolver]: `state.extra` is a navigation-time
/// snapshot that go_router does not persist across restarts/deep links, and it
/// goes stale if the setlist was renamed elsewhere (#91). Prefer the live
/// setlist from the stream; fall back to `extra` while the stream loads.
class SetlistRouteResolver extends ConsumerWidget {
  const SetlistRouteResolver({
    required this.setlistId,
    required this.bandId,
    required this.builder,
    this.extra,
    super.key,
  });

  final String? setlistId;
  final String? bandId;
  final Setlist? extra;
  final Widget Function(Setlist? setlist) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = bandId != null
        ? ref.watch(bandSetlistsProvider(bandId!)).asData?.value
        : ref.watch(setlistsProvider).asData?.value;
    if (setlists != null) {
      for (final candidate in setlists) {
        if (candidate.id == setlistId) return builder(candidate);
      }
    }
    return builder(extra);
  }
}
