import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';

import '../../helpers/mocks.dart';
import '../../helpers/routed_test_harness.dart';

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
      mockUser = MockDataHelper.createMockAppUser();
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
        MockDataHelper.createMockSong(
          id: '1',
          title: 'Song One',
          artist: 'Artist One',
          originalBPM: 120,
          originalKey: 'C',
          tags: ['practice'],
        ),
        MockDataHelper.createMockSong(
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
    });

    testWidgets('filters songs by title', (tester) async {
      final songs = [
        MockDataHelper.createMockSong(id: '1', title: 'Ballad', artist: 'A'),
        MockDataHelper.createMockSong(id: '2', title: 'Anthem', artist: 'B'),
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
      final songs = [
        MockDataHelper.createMockSong(id: '1', title: 'Ballad', artist: 'A'),
      ];

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
        MockDataHelper.createMockSong(
          id: '1',
          title: 'Song One',
          artist: 'Artist One',
        ),
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
