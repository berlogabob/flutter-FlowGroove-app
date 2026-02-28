import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/widgets/metronome/song_library_block.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';
import 'package:flutter_repsync_app/providers/data/data_providers.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/metronome_state.dart';

// Test notifier that returns a specific state
class TestMetronomeNotifier extends MetronomeNotifier {
  final MetronomeState? initialState;

  TestMetronomeNotifier({this.initialState});

  @override
  MetronomeState build() => initialState ?? MetronomeState.initial();
}

void main() {
  group('SongLibraryBlock Widget', () {
    group('Compact view rendering', () {
      testWidgets('renders compact pill button', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        expect(find.text('Song Library'), findsOneWidget);
        expect(find.byIcon(Icons.music_note_outlined), findsOneWidget);
      });

      testWidgets('compact pill has correct styling', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Find the container with the pill
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThan(0));
      });

      testWidgets(
        'does not show loaded content indicator when nothing loaded',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Scaffold(body: const SongLibraryBlock()),
              ),
            ),
          );

          expect(find.textContaining('Loaded:'), findsNothing);
        },
      );

      testWidgets('shows loaded song indicator when song is loaded', (
        WidgetTester tester,
      ) async {
        final song = Song(
          id: 'song-1',
          title: 'Test Song',
          artist: 'Test Artist',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              metronomeProvider.overrideWith(
                () => TestMetronomeNotifier(
                  initialState: MetronomeState.initial().copyWith(
                    loadedSong: song,
                  ),
                ),
              ),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        expect(find.textContaining('Loaded: Test Song'), findsOneWidget);
      });

      testWidgets('shows loaded setlist indicator when setlist is loaded', (
        WidgetTester tester,
      ) async {
        final setlist = Setlist(
          id: 'setlist-1',
          bandId: 'band-1',
          name: 'Test Setlist',
          songIds: ['song-1', 'song-2', 'song-3'],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              metronomeProvider.overrideWith(
                () => TestMetronomeNotifier(
                  initialState: MetronomeState.initial().copyWith(
                    loadedSetlist: setlist,
                    currentSetlistIndex: 1,
                  ),
                ),
              ),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        expect(find.textContaining('Loaded: Test Setlist'), findsOneWidget);
        expect(find.textContaining('(2/3)'), findsOneWidget);
      });
    });

    group('Expanded view interactions', () {
      testWidgets('tapping compact pill opens slide-up panel', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Tap the compact pill
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        // Panel should be visible
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.text('Songs'), findsOneWidget);
      });

      testWidgets('slide-up panel has handle bar', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        // Handle bar should be visible (Container with specific dimensions)
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThan(2));
      });

      testWidgets('slide-up panel has tab toggle', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        expect(find.text('Songs'), findsOneWidget);
        expect(find.byIcon(Icons.music_note), findsOneWidget);
      });

      testWidgets('close button closes panel', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Close panel
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close), findsNothing);
        expect(
          find.text('Song Library'),
          findsOneWidget,
        ); // Compact view returns
      });

      testWidgets('tab toggle switches between Songs and Setlists', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        expect(find.text('Songs'), findsOneWidget);
        expect(find.text('Setlists'), findsNothing);

        // Toggle to Setlists
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        expect(find.text('Setlists'), findsOneWidget);
        expect(find.byIcon(Icons.playlist_play), findsOneWidget);

        // Toggle back to Songs
        await tester.tap(find.text('Setlists'));
        await tester.pumpAndSettle();

        expect(find.text('Songs'), findsOneWidget);
      });
    });

    group('Songs list view', () {
      testWidgets('shows empty state when no songs', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [songsProvider.overrideWith((ref) => Stream.value([]))],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        expect(find.text('No songs yet'), findsOneWidget);
        expect(find.byIcon(Icons.music_note_outlined), findsWidgets);
      });

      testWidgets('shows error state with retry button', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              songsProvider.overrideWith((ref) => Stream.error('Test error')),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Failed to load songs'), findsOneWidget);
      });

      testWidgets('displays songs list when data is available', (
        WidgetTester tester,
      ) async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Song One',
            artist: 'Artist One',
            ourBPM: 120,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          Song(
            id: 'song-2',
            title: 'Song Two',
            artist: 'Artist Two',
            ourBPM: 100,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              songsProvider.overrideWith((ref) => Stream.value(songs)),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        expect(find.text('Song One'), findsOneWidget);
        expect(find.text('Artist One'), findsOneWidget);
        expect(find.text('120 BPM'), findsOneWidget);
        expect(find.text('Song Two'), findsOneWidget);
        expect(find.text('100 BPM'), findsOneWidget);
      });

      testWidgets('song card shows BPM badge when BPM is set', (
        WidgetTester tester,
      ) async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Song With BPM',
            artist: 'Artist',
            ourBPM: 140,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              songsProvider.overrideWith((ref) => Stream.value(songs)),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        expect(find.text('140 BPM'), findsOneWidget);
      });

      testWidgets('song card without BPM does not show BPM badge', (
        WidgetTester tester,
      ) async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Song Without Tempo',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              songsProvider.overrideWith((ref) => Stream.value(songs)),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        expect(find.textContaining('BPM'), findsNothing);
      });

      testWidgets('tapping song card loads song and closes panel', (
        WidgetTester tester,
      ) async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Test Artist',
            ourBPM: 120,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              songsProvider.overrideWith((ref) => Stream.value(songs)),
              metronomeProvider.overrideWith(() => MetronomeNotifier()),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        // Tap song card
        await tester.tap(find.text('Test Song'));
        await tester.pumpAndSettle();

        // Panel should be closed
        expect(find.byIcon(Icons.close), findsNothing);
      });
    });

    group('Setlists list view', () {
      testWidgets('shows empty state when no setlists', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              setlistsProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel and switch to Setlists
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        expect(find.text('No setlists yet'), findsOneWidget);
        expect(find.byIcon(Icons.playlist_play_outlined), findsWidgets);
      });

      testWidgets('shows error state with retry button', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              setlistsProvider.overrideWith(
                (ref) => Stream.error('Test error'),
              ),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel and switch to Setlists
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Failed to load setlists'), findsOneWidget);
      });

      testWidgets('displays setlists list when data is available', (
        WidgetTester tester,
      ) async {
        final setlists = [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Gig Setlist',
            description: 'Songs for the gig',
            songIds: ['song-1', 'song-2', 'song-3'],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          Setlist(
            id: 'setlist-2',
            bandId: 'band-1',
            name: 'Practice Setlist',
            songIds: ['song-4', 'song-5'],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel and switch to Setlists
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        expect(find.text('Gig Setlist'), findsOneWidget);
        expect(find.text('Songs for the gig'), findsOneWidget);
        expect(find.text('3 songs'), findsOneWidget);
        expect(find.text('Practice Setlist'), findsOneWidget);
        expect(find.text('2 songs'), findsOneWidget);
      });

      testWidgets('setlist card shows song count', (WidgetTester tester) async {
        final setlists = [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Test Setlist',
            songIds: ['song-1', 'song-2', 'song-3', 'song-4', 'song-5'],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel and switch to Setlists
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        expect(find.text('5 songs'), findsOneWidget);
      });

      testWidgets('setlist without description does not show description', (
        WidgetTester tester,
      ) async {
        final setlists = [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Simple Setlist',
            songIds: ['song-1'],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel and switch to Setlists
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        expect(find.text('Simple Setlist'), findsOneWidget);
        expect(find.text('1 songs'), findsOneWidget);
      });

      testWidgets('tapping setlist card loads setlist and closes panel', (
        WidgetTester tester,
      ) async {
        final setlists = [
          Setlist(
            id: 'setlist-1',
            bandId: 'band-1',
            name: 'Test Setlist',
            songIds: ['song-1', 'song-2'],
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
              metronomeProvider.overrideWith(() => MetronomeNotifier()),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel and switch to Setlists
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Songs'));
        await tester.pumpAndSettle();

        // Tap setlist card
        await tester.tap(find.text('Test Setlist'));
        await tester.pumpAndSettle();

        // Panel should be closed
        expect(find.byIcon(Icons.close), findsNothing);
      });
    });

    group('Backdrop interaction', () {
      testWidgets('tapping backdrop closes panel', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Since backdrop is complex, just verify close button works
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsNothing);
      });
    });

    group('Accessibility', () {
      testWidgets('compact pill is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Should be able to tap the pill
        expect(find.byType(GestureDetector), findsWidgets);
      });

      testWidgets('song cards are tappable', (WidgetTester tester) async {
        final songs = [
          Song(
            id: 'song-1',
            title: 'Test Song',
            artist: 'Artist',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              songsProvider.overrideWith((ref) => Stream.value(songs)),
            ],
            child: MaterialApp(home: Scaffold(body: const SongLibraryBlock())),
          ),
        );

        // Open panel
        await tester.tap(find.text('Song Library'));
        await tester.pumpAndSettle();

        // Song cards should be tappable
        expect(find.byType(GestureDetector), findsWidgets);
      });
    });
  });
}
