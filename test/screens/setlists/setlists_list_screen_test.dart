import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/screens/setlists/setlists_list_screen.dart';
import 'package:flutter_repsync_app/providers/data_providers.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import 'package:flutter_repsync_app/models/user.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/mocks.dart';
import '../login_screen_test.dart';

// Test notifier that returns a specific value
class TestAppUserNotifier extends AppUserNotifier {
  final AppUser? mockUser;

  TestAppUserNotifier(this.mockUser);

  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(mockUser);
}

void main() {
  group('SetlistsListScreen', () {
    late MockFirebaseAuth mockAuth;


    setUp(() {
      mockAuth = MockFirebaseAuth();

    });

    testWidgets('renders setlists list screen with title', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify screen title
      expect(findText('Setlists'), findsOneWidget);
    });

    testWidgets('displays search field', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify search field
      expect(findText('Search setlists...'), findsOneWidget);
      expect(findIcon(Icons.search), findsWidgets);
    });

    testWidgets('displays floating action button', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(findIcon(Icons.add), findsWidgets);
    });

    testWidgets('displays empty state when no setlists', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify empty state
      expect(findText('No setlists yet'), findsOneWidget);
      expect(findText('Create a setlist for your next gig'), findsOneWidget);
      expect(findText('Create Setlist'), findsOneWidget);
    });

    testWidgets('displays list of setlists', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Gig Setlist 1', songIds: ['s1', 's2', 's3']),
        MockDataHelper.createMockSetlist(id: '2', name: 'Gig Setlist 2', songIds: ['s1', 's2']),
        MockDataHelper.createMockSetlist(id: '3', name: 'Practice Setlist', songIds: ['s1']),
      ];

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify setlists are displayed
      expect(find.text('Gig Setlist 1'), findsOneWidget);
      expect(find.text('Gig Setlist 2'), findsOneWidget);
      expect(find.text('Practice Setlist'), findsOneWidget);
    });

    testWidgets('displays song count for each setlist', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Setlist 1', songIds: ['s1', 's2', 's3']),
        MockDataHelper.createMockSetlist(id: '2', name: 'Setlist 2', songIds: ['s1', 's2']),
        MockDataHelper.createMockSetlist(id: '3', name: 'Setlist 3', songIds: ['s1']),
      ];

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify song counts
      expect(find.text('3 songs'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
      expect(find.text('1 song'), findsOneWidget);
    });

    testWidgets('filters setlists by name', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Rock Gig', songIds: []),
        MockDataHelper.createMockSetlist(id: '2', name: 'Jazz Gig', songIds: []),
        MockDataHelper.createMockSetlist(id: '3', name: 'Pop Gig', songIds: []),
      ];

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Rock');
      await tester.pumpAndSettle();

      // Verify only matching setlist is displayed
      expect(find.text('Rock Gig'), findsOneWidget);
      expect(find.text('Jazz Gig'), findsNothing);
      expect(find.text('Pop Gig'), findsNothing);
    });

    testWidgets('filters setlists by description', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final setlists = [
        Setlist(id: '1', name: 'Gig 1', songIds: [], description: 'Rock concert', bandId: 'band1', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Setlist(id: '2', name: 'Gig 2', songIds: [], description: 'Jazz club', bandId: 'band1', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Setlist(id: '3', name: 'Gig 3', songIds: [], description: 'Pop festival', bandId: 'band1', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ];

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'jazz');
      await tester.pumpAndSettle();

      // Verify only matching setlist is displayed
      expect(find.text('Gig 1'), findsNothing);
      expect(find.text('Gig 2'), findsOneWidget);
      expect(find.text('Gig 3'), findsNothing);
    });

    testWidgets('displays search empty state when no results', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Gig Setlist', songIds: []),
      ];

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value(setlists)),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Enter search query with no results
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'nonexistent');
      await tester.pumpAndSettle();

      // Verify search empty state
      expect(findText('No results found'), findsOneWidget);
    });

    testWidgets('navigates to create setlist screen when tapping FAB', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigate = false;

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/create-setlist') {
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

    testWidgets('navigates to create setlist screen when tapping Create Setlist button', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigate = false;

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/create-setlist') {
              didNavigate = true;
            }
          }),
        ],
      );

      // Tap Create Setlist button
      await tester.tap(findText('Create Setlist'));
      await tester.pump();

      expect(didNavigate, isTrue);
    });

    testWidgets('shows loading indicator when loading setlists', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify screen renders
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays error message when error occurs', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.error(Exception('Failed to load setlists'))),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify error message
      expect(find.text('Error: Exception: Failed to load setlists'), findsOneWidget);
    });

    testWidgets('displays setlist cards with correct icons', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final setlist = MockDataHelper.createMockSetlist(id: '1', name: 'Test Setlist', songIds: ['s1', 's2']);

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify icons
      expect(findIcon(Icons.playlist_play), findsWidgets);
      expect(findIcon(Icons.edit), findsOneWidget);
      expect(findIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('displays band name when available', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final setlist = MockDataHelper.createMockSetlist(
        id: '1',
        name: 'Test Setlist',
        songIds: ['s1'],
        bandId: 'test-band-id',
      );

      await pumpAppWidget(
        tester,
        const SetlistsListScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
          songsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Verify band name is displayed
      expect(find.text('test-band-id'), findsOneWidget);
    });
  });
}
