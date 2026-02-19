import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/screens/home_screen.dart';
import 'package:flutter_repsync_app/providers/data_providers.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';
import 'package:flutter_repsync_app/models/song.dart';
import 'package:flutter_repsync_app/models/band.dart';
import 'package:flutter_repsync_app/models/setlist.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mocks.dart';
import 'login_screen_test.dart';

void main() {
  group('HomeScreen', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
    });

    testWidgets('renders home screen with app title', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(null),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify app title
      expect(findText('RepSync'), findsOneWidget);
    });

    testWidgets('displays greeting section with user name', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser(displayName: 'John');

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify greeting
      expect(findText('Hello, John!'), findsOneWidget);
      expect(findText('Ready to rock?'), findsOneWidget);
    });

    testWidgets('displays statistics section', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify statistics section title
      expect(findText('Statistics'), findsOneWidget);
      
      // Verify stat labels
      expect(findText('Songs'), findsOneWidget);
      expect(findText('Bands'), findsOneWidget);
      expect(findText('Setlists'), findsOneWidget);
    });

    testWidgets('displays correct statistics counts', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final songs = List.generate(5, (i) => MockDataHelper.createMockSong(id: 'song-$i'));
      final bands = List.generate(2, (i) => MockDataHelper.createMockBand(id: 'band-$i'));
      final setlists = List.generate(3, (i) => MockDataHelper.createMockSetlist(id: 'setlist-$i'));

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value(songs)),
          bandsProvider.overrideWithValue(Stream.value(bands)),
          setlistsProvider.overrideWithValue(Stream.value(setlists)),
        ],
      );

      // Verify counts
      expect(find.text('5'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('displays quick actions section', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify quick actions section title
      expect(findText('Quick Actions'), findsOneWidget);
      
      // Verify action buttons
      expect(find.text('+ Song'), findsOneWidget);
      expect(find.text('+ Group'), findsOneWidget);
      expect(find.text('+ Setlist'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
    });

    testWidgets('displays tools section', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify tools section title
      expect(findText('Tools'), findsOneWidget);
      
      // Verify tool labels
      expect(findText('Tuner'), findsOneWidget);
      expect(findText('Metronome'), findsOneWidget);
      
      // Verify "Soon" badges
      expect(find.text('Soon'), findsNWidgets(2));
    });

    testWidgets('displays loading state when user data is loading', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(null),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify loading text appears
      expect(find.text('Hello, Loading...!'), findsOneWidget);
    });

    testWidgets('displays user initial in avatar', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser(displayName: 'Alice');

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify avatar with initial
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('navigates to songs screen when tapping Songs stat', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToSongs = false;

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/songs') {
              didNavigateToSongs = true;
            }
          }),
        ],
      );

      // Find and tap the Songs stat card
      final songsStat = find.text('Songs');
      await tester.tap(songsStat.first);
      await tester.pump();

      expect(didNavigateToSongs, isTrue);
    });

    testWidgets('navigates to bands screen when tapping Bands stat', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToBands = false;

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/bands') {
              didNavigateToBands = true;
            }
          }),
        ],
      );

      // Find and tap the Bands stat card
      final bandsStat = find.text('Bands');
      await tester.tap(bandsStat.first);
      await tester.pump();

      expect(didNavigateToBands, isTrue);
    });

    testWidgets('navigates to setlists screen when tapping Setlists stat', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToSetlists = false;

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/setlists') {
              didNavigateToSetlists = true;
            }
          }),
        ],
      );

      // Find and tap the Setlists stat card
      final setlistsStat = find.text('Setlists');
      await tester.tap(setlistsStat.first);
      await tester.pump();

      expect(didNavigateToSetlists, isTrue);
    });

    testWidgets('navigates to add song screen when tapping + Song', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToAddSong = false;

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/add-song') {
              didNavigateToAddSong = true;
            }
          }),
        ],
      );

      // Find and tap the + Song button
      await tester.tap(find.text('+ Song'));
      await tester.pump();

      expect(didNavigateToAddSong, isTrue);
    });

    testWidgets('navigates to create band screen when tapping + Group', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToCreateBand = false;

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/create-band') {
              didNavigateToCreateBand = true;
            }
          }),
        ],
      );

      // Find and tap the + Group button
      await tester.tap(find.text('+ Group'));
      await tester.pump();

      expect(didNavigateToCreateBand, isTrue);
    });

    testWidgets('navigates to create setlist screen when tapping + Setlist', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToCreateSetlist = false;

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/create-setlist') {
              didNavigateToCreateSetlist = true;
            }
          }),
        ],
      );

      // Find and tap the + Setlist button
      await tester.tap(find.text('+ Setlist'));
      await tester.pump();

      expect(didNavigateToCreateSetlist, isTrue);
    });

    testWidgets('displays correct icons for statistics', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify icons
      expect(findIcon(Icons.music_note), findsWidgets);
      expect(findIcon(Icons.groups), findsWidgets);
      expect(findIcon(Icons.queue_music), findsWidgets);
    });

    testWidgets('displays correct icons for quick actions', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const HomeScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          songsProvider.overrideWithValue(Stream.value([])),
          bandsProvider.overrideWithValue(Stream.value([])),
          setlistsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify icons
      expect(findIcon(Icons.add), findsWidgets);
      expect(findIcon(Icons.group_add), findsWidgets);
      expect(findIcon(Icons.playlist_add), findsWidgets);
      expect(findIcon(Icons.library_music), findsWidgets);
    });
  });
}
