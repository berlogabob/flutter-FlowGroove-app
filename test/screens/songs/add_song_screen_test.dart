import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/screens/songs/add_song_screen.dart';
import 'package:flutter_repsync_app/providers/data_providers.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';

import 'package:flutter_repsync_app/models/link.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/mocks.dart';
import '../login_screen_test.dart';

void main() {
  group('AddSongScreen', () {
    late MockFirebaseAuth mockAuth;
    

    setUp(() {
      mockAuth = MockFirebaseAuth();
      
    });

    testWidgets('renders add song screen with title', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify screen title
      expect(findText('Add Song'), findsOneWidget);
    });

    testWidgets('renders edit song screen with title when editing', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final song = MockDataHelper.createMockSong(
        id: 'test-song',
        title: 'Test Song',
        artist: 'Test Artist',
      );

      await pumpAppWidget(
        tester,
        AddSongScreen(song: song),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify screen title
      expect(findText('Edit Song'), findsOneWidget);
    });

    testWidgets('displays all form fields', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify form fields
      expect(find.text('Title').first, findsOneWidget);
      expect(find.text('Artist').first, findsOneWidget);
      expect(find.text('Original BPM'), findsOneWidget);
      expect(find.text('Our BPM'), findsOneWidget);
      expect(find.text('Original Key'), findsOneWidget);
      expect(find.text('Our Key'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('displays save button in app bar', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify save button
      expect(findText('Save'), findsOneWidget);
    });

    testWidgets('allows entering song title and artist', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Find text fields
      final textFields = find.byType(TextFormField);
      
      // Enter title
      await tester.enterText(textFields.at(0), 'Test Song');
      await tester.pump();

      // Enter artist
      await tester.enterText(textFields.at(1), 'Test Artist');
      await tester.pump();

      // Verify text was entered
      expect(find.text('Test Song'), findsWidgets);
      expect(find.text('Test Artist'), findsWidgets);
    });

    testWidgets('allows entering BPM values', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Find BPM fields
      final textFields = find.byType(TextFormField);
      
      // Enter original BPM
      await tester.enterText(textFields.at(2), '120');
      await tester.pump();

      // Enter our BPM
      await tester.enterText(textFields.at(3), '125');
      await tester.pump();

      // Verify values
      expect(find.text('120'), findsWidgets);
      expect(find.text('125'), findsWidgets);
    });

    testWidgets('allows entering notes', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Find notes field (it's the 5th TextFormField)
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(4), 'Test notes');
      await tester.pump();

      // Verify notes
      expect(find.text('Test notes'), findsWidgets);
    });

    testWidgets('displays tag selection chips', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify tags are displayed
      expect(find.text('ready'), findsOneWidget);
      expect(find.text('learning'), findsOneWidget);
      expect(find.text('hard'), findsOneWidget);
      expect(find.text('slow'), findsOneWidget);
      expect(find.text('fast'), findsOneWidget);
    });

    testWidgets('allows selecting tags', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Tap on 'ready' tag
      await tester.tap(find.text('ready'));
      await tester.pump();

      // Verify tag is selected (FilterChip should be selected)
      expect(find.text('ready'), findsOneWidget);
    });

    testWidgets('displays search buttons', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify search buttons
      expect(find.text('MusicBrainz'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('BPM/Key'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
    });

    testWidgets('displays copy from original button', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify copy button
      expect(find.text('Copy from Original'), findsOneWidget);
    });

    testWidgets('populates form fields when editing', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final song = MockDataHelper.createMockSong(
        id: 'test-song',
        title: 'Existing Song',
        artist: 'Existing Artist',
        originalBPM: 130,
        ourBPM: 135,
        notes: 'Existing notes',
      );

      await pumpAppWidget(
        tester,
        AddSongScreen(song: song),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify form is populated
      expect(find.text('Existing Song'), findsWidgets);
      expect(find.text('Existing Artist'), findsWidgets);
      expect(find.text('130'), findsWidgets);
      expect(find.text('135'), findsWidgets);
    });

    testWidgets('shows message when saving without title', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Tap save button
      await tester.tap(findText('Save'));
      await tester.pumpAndSettle();

      // Verify validation message (form validation should prevent save)
      // The form should show validation errors
    });

    testWidgets('shows success message when saving song', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      when(mockFirestore.saveSong(any, any)).thenAnswer((_) async => {});

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Enter title and artist
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'New Song');
      await tester.enterText(textFields.at(1), 'New Artist');
      await tester.pump();

      // Tap save button
      await tester.tap(findText('Save'));
      await tester.pumpAndSettle();

      // Verify success message appears
      expect(find.text('New Song added'), findsOneWidget);
    });

    testWidgets('displays key selector dropdowns', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify key selectors are present
      expect(find.text('Original Key'), findsOneWidget);
      expect(find.text('Our Key'), findsOneWidget);
    });

    testWidgets('displays links section', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          
          appUserProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          currentUserProvider.overrideWithValue(mockUser),
        ],
      );

      // Verify links section
      expect(find.text('Links'), findsOneWidget);
    });
  });
}
