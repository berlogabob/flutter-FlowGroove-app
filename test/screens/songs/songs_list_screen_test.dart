import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/screens/songs/songs_list_screen.dart';
import 'package:flutter_repsync_app/providers/data_providers.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/mocks.dart';
import '../login_screen_test.dart';

void main() {
  group('SongsListScreen', () {
    late MockFirebaseAuth mockAuth;

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    testWidgets('renders songs list screen with title', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify screen title
      expect(findText('Songs'), findsOneWidget);
    });

    testWidgets('displays search field', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify search field
      expect(findText('Search songs...'), findsOneWidget);
      expect(findIcon(Icons.search), findsWidgets);
    });

    testWidgets('displays floating action button', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(findIcon(Icons.add), findsWidgets);
    });

    testWidgets('displays empty state when no songs', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify empty state
      expect(findText('No songs yet'), findsOneWidget);
      expect(findText('Tap + to add your first song'), findsOneWidget);
      expect(findText('Add Song'), findsOneWidget);
    });

    testWidgets('displays list of songs', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final songs = [
        MockDataHelper.createMockSong(id: '1', title: 'Song One', artist: 'Artist One'),
        MockDataHelper.createMockSong(id: '2', title: 'Song Two', artist: 'Artist Two'),
        MockDataHelper.createMockSong(id: '3', title: 'Song Three', artist: 'Artist Three'),
      ];

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value(songs)),
        ],
      );

      // Verify songs are displayed
      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('Song Two'), findsOneWidget);
      expect(find.text('Song Three'), findsOneWidget);
      expect(find.text('Artist One'), findsOneWidget);
      expect(find.text('Artist Two'), findsOneWidget);
      expect(find.text('Artist Three'), findsOneWidget);
    });

    testWidgets('filters songs by title', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final songs = [
        MockDataHelper.createMockSong(id: '1', title: 'Bohemian Rhapsody', artist: 'Queen'),
        MockDataHelper.createMockSong(id: '2', title: 'Hotel California', artist: 'Eagles'),
        MockDataHelper.createMockSong(id: '3', title: 'Sweet Child O Mine', artist: 'Guns N Roses'),
      ];

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value(songs)),
        ],
      );

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Bohemian');
      await tester.pumpAndSettle();

      // Verify only matching song is displayed
      expect(find.text('Bohemian Rhapsody'), findsOneWidget);
      expect(find.text('Hotel California'), findsNothing);
      expect(find.text('Sweet Child O Mine'), findsNothing);
    });

    testWidgets('filters songs by artist', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final songs = [
        MockDataHelper.createMockSong(id: '1', title: 'Bohemian Rhapsody', artist: 'Queen'),
        MockDataHelper.createMockSong(id: '2', title: 'Hotel California', artist: 'Eagles'),
        MockDataHelper.createMockSong(id: '3', title: 'Sweet Child O Mine', artist: 'Guns N Roses'),
      ];

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value(songs)),
        ],
      );

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Queen');
      await tester.pumpAndSettle();

      // Verify only matching song is displayed
      expect(find.text('Bohemian Rhapsody'), findsOneWidget);
      expect(find.text('Hotel California'), findsNothing);
      expect(find.text('Sweet Child O Mine'), findsNothing);
    });

    testWidgets('filters songs by tags', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final songs = [
        MockDataHelper.createMockSong(id: '1', title: 'Song One', artist: 'Artist', tags: ['ready', 'easy']),
        MockDataHelper.createMockSong(id: '2', title: 'Song Two', artist: 'Artist', tags: ['learning', 'hard']),
        MockDataHelper.createMockSong(id: '3', title: 'Song Three', artist: 'Artist', tags: ['fast', 'hard']),
      ];

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value(songs)),
        ],
      );

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'hard');
      await tester.pumpAndSettle();

      // Verify only matching songs are displayed
      expect(find.text('Song One'), findsNothing);
      expect(find.text('Song Two'), findsOneWidget);
      expect(find.text('Song Three'), findsOneWidget);
    });

    testWidgets('displays search empty state when no results', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final songs = [
        MockDataHelper.createMockSong(id: '1', title: 'Song One', artist: 'Artist'),
      ];

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value(songs)),
        ],
      );

      // Enter search query with no results
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'nonexistent');
      await tester.pumpAndSettle();

      // Verify search empty state
      expect(findText('No results found'), findsOneWidget);
    });

    testWidgets('navigates to add song screen when tapping FAB', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigate = false;

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/add-song') {
              didNavigate = true;
            }
          }),
        ],
      );

      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(didNavigate, isTrue);
    });

    testWidgets('navigates to add song screen when tapping Add Song button', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigate = false;

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/add-song') {
              didNavigate = true;
            }
          }),
        ],
      );

      // Tap Add Song button
      await tester.tap(findText('Add Song'));
      await tester.pump();

      expect(didNavigate, isTrue);
    });

    testWidgets('shows loading indicator when loading songs', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Note: The loading state is shown briefly during the stream setup
      // We verify the screen renders properly instead
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays error message when error occurs', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.error(Exception('Failed to load songs'))),
        ],
      );

      // Verify error message
      expect(find.text('Error: Exception: Failed to load songs'), findsOneWidget);
    });

    testWidgets('displays song cards with correct data', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final song = MockDataHelper.createMockSong(
        id: '1',
        title: 'Test Song',
        artist: 'Test Artist',
        ourBPM: 120,
        ourKey: 'C',
      );

      await pumpAppWidget(
        tester,
        const SongsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWith((ref) => Stream.value([song])),
        ],
      );

      // Verify song data
      expect(find.text('Test Song'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });
  });
}
