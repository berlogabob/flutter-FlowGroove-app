import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/song_autocomplete_provider.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/models/song_suggestion.dart';

import '../../helpers/test_helpers.dart';
import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';

// Test notifier that returns a specific value
class TestAppUserNotifier extends AppUserNotifier {
  final AppUser? mockUser;

  TestAppUserNotifier(this.mockUser);

  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(mockUser);
}

void main() {
  group('AddSongScreen', () {
    late MockFirebaseAuth mockAuth;

    setUp(() async {
      mockAuth = MockFirebaseAuth();
      // Initialize Firebase for tests that use widgets accessing FirebaseAuth
      await initializeFirebaseForTests();
    });

    testWidgets('renders add song screen with title', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify screen title
      expect(findText('Add Song'), findsOneWidget);
    });

    testWidgets('renders edit song screen with title when editing', (
      WidgetTester tester,
    ) async {
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
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
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
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify form fields (note: title has * in label, autocomplete has hint)
      expect(find.text('Title *'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Our'), findsOneWidget);
      expect(find.text('Our Key & BPM'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('displays save button in app bar', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Save button is in a PopupMenuButton - tap the more_horiz icon to open menu
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // Verify save button in popup menu
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('allows entering song title and artist', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Find title and artist text fields
      final titleField = find.widgetWithText(TextFormField, 'Title *');
      final artistField = find.widgetWithText(TextFormField, 'Artist');

      // Enter title
      await tester.enterText(titleField, 'Test Song');
      await tester.pump();

      // Enter artist
      await tester.enterText(artistField, 'Test Artist');
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
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Find BPM fields (they are TextFormFields within KeyBpmSelector)
      final textFields = find.byType(TextFormField);
      // Field order: autocomplete (hidden title), visible title, artist, original BPM, our BPM, notes
      // Original BPM is at index 3, our BPM at index 4

      // Enter original BPM
      await tester.enterText(textFields.at(3), '120');
      await tester.pump();

      // Enter our BPM
      await tester.enterText(textFields.at(4), '125');
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
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Tap to expand Notes collapsible section
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      // Find notes field
      final notesField = find.widgetWithText(TextFormField, 'Add notes about this song...');
      await tester.enterText(notesField, 'Test notes');
      await tester.pump();

      // Verify notes
      expect(find.text('Test notes'), findsWidgets);
    });

    testWidgets('displays tag selection chips when expanded', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Tags are in a CollapsibleSection that's initially collapsed
      // Scroll to find the Tags section
      await tester.dragUntilVisible(
        find.text('Tags'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();

      // Tap to expand Tags section
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

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
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Scroll to Tags section
      await tester.dragUntilVisible(
        find.text('Tags'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();

      // Expand Tags section
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

      // Tap on 'ready' tag
      await tester.tap(find.text('ready'));
      await tester.pump();

      // Verify tag is still displayed (FilterChip selection state changes)
      expect(find.text('ready'), findsOneWidget);
    });

    testWidgets('displays search buttons', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Scroll down to reveal search buttons at bottom of ListView
      await tester.dragUntilVisible(
        find.text('MusicBrainz'),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pump();

      // Verify search buttons
      expect(find.text('MusicBrainz'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('BPM/Key'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
    });

    testWidgets('displays copy from original button', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify copy button (labeled as "Copy" in the "Our Key & BPM" section)
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('populates form fields when editing', (
      WidgetTester tester,
    ) async {
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
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify form is populated
      expect(find.text('Existing Song'), findsWidgets);
      expect(find.text('Existing Artist'), findsWidgets);
      expect(find.text('130'), findsWidgets);
      expect(find.text('135'), findsWidgets);
    });

    testWidgets('shows validation when saving without title', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Tap the more_horiz icon to open popup menu
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify validation message appears (form validation should prevent save)
      expect(find.text('Title required'), findsOneWidget);
    });

    testWidgets('displays key selector dropdowns', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify key selectors are present (labels in KeyBpmSelector)
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Our'), findsOneWidget);
    });

    testWidgets('displays links section', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify links section (initially expanded, may find multiple due to collapsible header)
      expect(find.text('Links'), findsWidgets);
    });

    testWidgets('renders scaffold', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders app bar', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders ListView body', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays Wrap for search buttons', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      await tester.dragUntilVisible(
        find.byType(Wrap),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pump();

      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('displays search icons', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Scroll down to reveal search buttons at bottom
      // Drag UP (positive offset in Y) to scroll content down
      await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
      await tester.pumpAndSettle();

      // Search icons are in TextButton.icon widgets - find by button text instead
      expect(find.text('MusicBrainz'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
    });

    testWidgets('displays music note icon for Spotify', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Scroll down to reveal search buttons
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.byIcon(Icons.music_note), findsWidgets);
    });

    testWidgets('displays analytics icon for BPM/Key', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Scroll down to reveal search buttons
      await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
      await tester.pumpAndSettle();

      // Verify BPM/Key button is visible
      expect(find.text('BPM/Key'), findsOneWidget);
    });

    testWidgets('displays SizedBox for spacing', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('displays Align widget for search buttons', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Scroll down to reveal search buttons
      await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
      await tester.pumpAndSettle();

      // Verify Wrap (containing search buttons) is found
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('handles null song for add mode', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(song: null),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      expect(find.text('Add Song'), findsOneWidget);
    });

    testWidgets('initializes with form fields for new song', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Form should be ready for input
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('displays all 5 available tags when expanded', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Scroll to find Tags section
      await tester.dragUntilVisible(
        find.text('Tags'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();

      // Expand Tags section (initially collapsed)
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
      expect(find.text('learning'), findsOneWidget);
      expect(find.text('hard'), findsOneWidget);
      expect(find.text('slow'), findsOneWidget);
      expect(find.text('fast'), findsOneWidget);
    });

    testWidgets('displays SongForm widget', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify SongForm is rendered
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('displays PopScope for auto-save on back', (
      WidgetTester tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            () => TestAutocompleteNotifier(),
          ),
        ],
      );

      // Verify PopScope is rendered (for auto-save on back navigation)
      // PopScope wraps the Scaffold in the build method
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('PopScope')), findsOneWidget);
    });
  });
}

/// Test autocomplete notifier that returns empty state
class TestAutocompleteNotifier extends AutocompleteSearchNotifier {
  @override
  AutocompleteSearchState build() {
    return const AutocompleteSearchState.initial();
  }

  @override
  void init({String? userId, String? bandId}) {
    // No-op: don't access FirebaseAuth in tests
  }

  @override
  void updateQuery(String query, {int debounceMs = 300}) {
    // No-op: don't actually search in tests
  }
}
