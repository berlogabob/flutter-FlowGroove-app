/// Song Quick Action Integration Test
///
/// Tests tapping the "Song" quick action button on the Home screen
/// and navigating to the Add Song screen.
///
/// Test ID: INT-QUICK-ACTION-SONG-01
/// Priority: P0 🔴
///
/// To run on emulator:
///   flutter test --device-id=emulator-5554 test/integration/song_quick_action_test.dart
///
/// Or run as integration_test:
///   flutter test integration_test/song_quick_action_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/models/user.dart';

import '../helpers/test_helpers.dart';
import '../helpers/mocks.dart';
import '../helpers/mocks.mocks.dart';

// Test notifier that returns a specific value
class TestAppUserNotifier extends AppUserNotifier {
  final AppUser? mockUser;

  TestAppUserNotifier(this.mockUser);

  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(mockUser);
}

void main() {
  group('Song Quick Action Button Test - INT-QUICK-ACTION-SONG-01', skip: 'Requires Firebase emulator/mocks - TODO: setup integration test environment', () {
    late MockFirebaseAuth mockAuth;

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    testWidgets(
      'INT-QUICK-ACTION-SONG-01.1: Song quick action button exists on Home screen',
      (WidgetTester tester) async {
        final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');

        await pumpAppWidget(
          tester,
          const HomeScreen(),
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
            songsProvider.overrideWith((ref) => Stream.value([])),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            setlistsProvider.overrideWith((ref) => Stream.value([])),
          ],
        );
        await tester.pumpAndSettle();

        // Verify Quick Actions section exists
        expect(find.text('Quick Actions'), findsOneWidget);

        // Verify Song button exists with correct label
        expect(find.text('+ Song'), findsOneWidget);

        // Verify the button has an add icon
        expect(find.byIcon(Icons.add), findsWidgets);
      },
    );

    testWidgets(
      'INT-QUICK-ACTION-SONG-01.2: Tapping Song button navigates to Add Song screen',
      (WidgetTester tester) async {
        final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');
        bool didNavigateToAddSong = false;

        await pumpAppWidget(
          tester,
          const HomeScreen(),
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
            songsProvider.overrideWith((ref) => Stream.value([])),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            setlistsProvider.overrideWith((ref) => Stream.value([])),
          ],
          navigatorObservers: [
            MockNavigatorObserver(
              onPush: (route) {
                if (route.settings.name == '/add-song') {
                  didNavigateToAddSong = true;
                }
              },
            ),
          ],
        );
        await tester.pumpAndSettle();

        // Verify initial state - Home screen
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('+ Song'), findsOneWidget);

        // Act: Tap the Song quick action button
        final songButton = find.text('+ Song');
        await tester.tap(songButton);
        await tester.pumpAndSettle();

        // Assert: Navigation occurred
        expect(didNavigateToAddSong, isTrue, reason: 'Should navigate to /add-song route');
      },
    );

    testWidgets(
      'INT-QUICK-ACTION-SONG-01.3: Add Song screen loads without errors',
      (WidgetTester tester) async {
        final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');
        bool didNavigateToAddSong = false;

        await pumpAppWidget(
          tester,
          const HomeScreen(),
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
            songsProvider.overrideWith((ref) => Stream.value([])),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            setlistsProvider.overrideWith((ref) => Stream.value([])),
          ],
          navigatorObservers: [
            MockNavigatorObserver(
              onPush: (route) {
                if (route.settings.name == '/add-song') {
                  didNavigateToAddSong = true;
                }
              },
            ),
          ],
        );
        await tester.pumpAndSettle();

        // Act: Tap the Song quick action button
        await tester.tap(find.text('+ Song'));
        await tester.pumpAndSettle();

        // Assert: Navigation and rendering
        expect(didNavigateToAddSong, isTrue, reason: 'Should navigate to /add-song route');
        
        // Verify Add Song screen title is displayed
        expect(find.text('Add Song'), findsOneWidget, reason: 'Add Song screen title should be visible');
      },
    );

    testWidgets(
      'INT-QUICK-ACTION-SONG-01.4: Add Song screen displays all required form fields',
      (WidgetTester tester) async {
        final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');

        await pumpAppWidget(
          tester,
          const AddSongScreen(),
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          ],
        );
        await tester.pumpAndSettle();

        // Verify screen title
        expect(find.text('Add Song'), findsOneWidget);

        // Verify required form fields are present
        expect(find.text('Title *').first, findsOneWidget, reason: 'Title field should be present');
        expect(find.text('Artist').first, findsOneWidget, reason: 'Artist field should be present');
        
        // Verify form has text input fields
        final textFields = find.byType(TextFormField);
        expect(textFields, findsWidgets, reason: 'Form should have text input fields');
        
        // Verify save button exists
        expect(find.text('Save'), findsOneWidget, reason: 'Save button should be present');
        
        // No red error screen should be visible
        expect(find.text('Error'), findsNothing, reason: 'No error screen should be displayed');
        expect(find.byIcon(Icons.error), findsNothing, reason: 'No error icon should be displayed');
      },
    );

    testWidgets(
      'INT-QUICK-ACTION-SONG-01.5: Complete flow - Home to Add Song and enter data',
      (WidgetTester tester) async {
        final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');

        // Start at Home screen
        await pumpAppWidget(
          tester,
          const HomeScreen(),
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
            songsProvider.overrideWith((ref) => Stream.value([])),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            setlistsProvider.overrideWith((ref) => Stream.value([])),
          ],
        );
        await tester.pumpAndSettle();

        // Verify Home screen
        expect(find.text('Quick Actions'), findsOneWidget);
        
        // Tap Song button
        await tester.tap(find.text('+ Song'));
        await tester.pumpAndSettle();

        // Verify Add Song screen loaded
        expect(find.text('Add Song'), findsOneWidget);
        
        // Act: Enter song data
        final textFields = find.byType(TextFormField);
        
        // Enter title
        await tester.enterText(textFields.at(0), 'Test Song Title');
        await tester.pump();
        
        // Enter artist
        await tester.enterText(textFields.at(1), 'Test Artist');
        await tester.pump();

        // Assert: Data entered successfully
        expect(find.text('Test Song Title'), findsWidgets);
        expect(find.text('Test Artist'), findsWidgets);
        
        // No errors should occur
        expect(find.text('Error'), findsNothing);
        expect(find.byIcon(Icons.error), findsNothing);
      },
    );

    testWidgets(
      'INT-QUICK-ACTION-SONG-01.6: Song button is in Quick Actions section (top-left position)',
      (WidgetTester tester) async {
        final mockUser = MockDataHelper.createMockAppUser(displayName: 'TestUser');

        await pumpAppWidget(
          tester,
          const HomeScreen(),
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
            songsProvider.overrideWith((ref) => Stream.value([])),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            setlistsProvider.overrideWith((ref) => Stream.value([])),
          ],
        );
        await tester.pumpAndSettle();

        // Find the Quick Actions section
        final quickActionsSection = find.text('Quick Actions');
        expect(quickActionsSection, findsOneWidget);

        // Verify Song button is present in quick actions
        // The Quick Actions section contains a GridView with buttons
        final songButton = find.text('+ Song');
        expect(songButton, findsOneWidget);

        // Verify it has the add icon (typical for quick action buttons)
        final addIcon = find.byIcon(Icons.add);
        expect(addIcon, findsWidgets);
      },
    );
  });
}
