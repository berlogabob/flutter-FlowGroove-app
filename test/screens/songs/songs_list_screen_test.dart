import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/screens/songs/songs_list_screen.dart';

import '../../helpers/metronome_test_runtime.dart';
import '../../helpers/routed_test_harness.dart';

AppUser createTestUser() {
  return AppUser(
    uid: 'test-user-id',
    displayName: 'Test User',
    email: 'test@example.com',
    createdAt: DateTime(2024, 1, 1),
  );
}

Song createTestSong({
  String id = 'test-song-id',
  String title = 'Test Song',
  String artist = 'Test Artist',
  int? originalBPM,
  int? ourBPM,
  String? originalKey,
  String? ourKey,
  List<String> tags = const [],
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    originalBPM: originalBPM,
    ourBPM: ourBPM,
    originalKey: originalKey,
    ourKey: ourKey,
    tags: tags,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('SongsListScreen', () {
    late AppUser mockUser;

    List<dynamic> overridesFor({
      required Stream<List<Song>> songs,
      Stream<List<Band>>? bands,
    }) => [
      appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
      songsProvider.overrideWith((ref) => songs),
      bandsProvider.overrideWith(
        (ref) => bands ?? Stream<List<Band>>.value([]),
      ),
    ];

    setUp(() {
      mockUser = createTestUser();
    });

    testWidgets('renders songs list screen with title and search', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value([])),
      );

      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Search songs...'), findsOneWidget);
      expect(find.text('Filters:'), findsOneWidget);
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('displays empty state when no songs exist', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value([])),
      );

      expect(find.text('No songs yet'), findsOneWidget);
      expect(find.text('Tap + to add your first song'), findsOneWidget);
      expect(find.text('Add Song'), findsOneWidget);
    });

    testWidgets('displays song cards with artist, BPM, key, and tags', (
      tester,
    ) async {
      final songs = [
        createTestSong(
          id: '1',
          title: 'Song One',
          artist: 'Artist One',
          originalBPM: 120,
          originalKey: 'C',
          tags: ['practice'],
        ),
        createTestSong(
          id: '2',
          title: 'Song Two',
          artist: 'Artist Two',
          ourBPM: 130,
          ourKey: 'G',
        ),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value(songs)),
      );

      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('Artist One'), findsOneWidget);
      expect(find.text('120 BPM'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('Song Two'), findsOneWidget);
      expect(find.text('130 BPM'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsWidgets);
      expect(find.byTooltip('Open in Tuner'), findsNWidgets(2));
    });

    testWidgets('shows metronome action for songs with tempo data', (
      tester,
    ) async {
      final songs = [
        createTestSong(
          id: 'tempo-song',
          title: 'Tempo Song',
          artist: 'Practice Artist',
          ourBPM: 130,
        ),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value(songs)),
      );

      expect(find.byTooltip('Open in Metronome'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('open-in-metronome-action')),
        findsOneWidget,
      );
    });

    testWidgets('shows metronome action for saved beat pattern settings', (
      tester,
    ) async {
      final songs = [
        createTestSong(
          id: 'pattern-song',
          title: 'Pattern Song',
          artist: 'Practice Artist',
        ).copyWith(accentBeats: 5, regularBeats: 2),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value(songs)),
      );

      expect(find.byTooltip('Open in Metronome'), findsOneWidget);
    });

    testWidgets('opens song settings in metronome without starting playback', (
      tester,
    ) async {
      final song =
          createTestSong(
            id: 'metronome-song',
            title: 'Metronome Song',
            artist: 'Practice Artist',
            ourBPM: 142,
          ).copyWith(
            accentBeats: 5,
            regularBeats: 2,
            beatModes: const [
              [BeatMode.accent, BeatMode.normal],
              [BeatMode.normal, BeatMode.silent],
            ],
          );
      final runtime = MetronomeTestRuntime();
      final container = ProviderContainer(
        overrides: [
          ...overridesFor(songs: Stream<List<Song>>.value([song])),
          ...buildMetronomeTestOverrides(
            runtime: runtime,
            overrideMetronomeProvider: true,
          ),
        ].cast(),
      );
      final router = createRoutedTestRouter(
        initialLocation: '/main/songs',
        routes: [
          GoRoute(
            path: '/main/songs',
            name: 'songs',
            builder: (context, state) => const SongsListScreen(),
          ),
          GoRoute(
            path: '/main/metronome',
            name: 'metronome',
            builder: (context, state) => const TestRouteMarker('metronome'),
          ),
        ],
      );

      addTearDown(container.dispose);
      addTearDown(router.dispose);
      addTearDown(runtime.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Open in Metronome'));
      await tester.pumpAndSettle();

      final metronomeState = container.read(metronomeProvider);
      expect(currentRouterUri(router).path, '/main/metronome');
      expect(find.text('route:metronome'), findsOneWidget);
      expect(metronomeState.loadedSong?.id, 'metronome-song');
      expect(metronomeState.bpm, 142);
      expect(metronomeState.accentBeats, 5);
      expect(metronomeState.regularBeats, 2);
      expect(metronomeState.beatModes, song.beatModes);
      expect(metronomeState.isPlaying, isFalse);
    });

    testWidgets('filters songs by title', (tester) async {
      final songs = [
        createTestSong(id: '1', title: 'Ballad', artist: 'A'),
        createTestSong(id: '2', title: 'Anthem', artist: 'B'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value(songs)),
      );

      await tester.enterText(find.byType(TextField), 'Ballad');
      await tester.pump();

      expect(find.text('Ballad'), findsWidgets);
      expect(find.text('Anthem'), findsNothing);
    });

    testWidgets('shows search empty state when no songs match', (tester) async {
      final songs = [createTestSong(id: '1', title: 'Ballad', artist: 'A')];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value(songs)),
      );

      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Try searching for "missing"'), findsOneWidget);
    });

    testWidgets('navigates to add song from FAB', (tester) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value([])),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/songs/add');
      expect(find.text('route:add-song'), findsOneWidget);
    });

    testWidgets('navigates to add song from empty state CTA', (tester) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value([])),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Song'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/songs/add');
      expect(find.text('route:add-song'), findsOneWidget);
    });

    testWidgets('opens CSV import dialog from app bar menu', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value([])),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import from CSV'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Import Songs from CSV'), findsOneWidget);
      expect(find.text('Select CSV File'), findsOneWidget);
      expect(find.text('Paste from Clipboard'), findsOneWidget);
    });

    testWidgets('opens CSV export dialog from app bar menu', (tester) async {
      final songs = [
        createTestSong(id: '1', title: 'Song One', artist: 'Artist One'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: Stream<List<Song>>.value(songs)),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export to CSV'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Export Songs to CSV'), findsOneWidget);
      expect(find.text('Export 1 song(s) to CSV file:'), findsOneWidget);
      expect(find.text('Save to Device'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('shows loading indicator while songs are loading', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/songs',
        overrides: overridesFor(songs: const Stream<List<Song>>.empty()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
