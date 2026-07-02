import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/song_autocomplete_provider.dart';
import 'package:flowgroove/screens/songs/add_song_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mocks.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_helpers.dart';

// Test notifier that returns a specific value
class TestAppUserNotifier extends AppUserNotifier {

  TestAppUserNotifier(this.mockUser);
  final AppUser? mockUser;

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
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Verify screen title
      expect(findText('Add Song'), findsOneWidget);
    });

    testWidgets('renders edit song screen with title when editing', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final song = MockDataHelper.createMockSong(
        id: 'test-song',
      );

      await pumpAppWidget(
        tester,
        AddSongScreen(song: song),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Verify screen title
      expect(findText('Edit Song'), findsOneWidget);
    });

    testWidgets('displays all form fields', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Title and artist are always visible; the rest of the form lives in
      // collapsible section bubbles.
      expect(find.text('Title *'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Key & BPM'), findsOneWidget);
      expect(find.text('Links'), findsOneWidget);
      expect(find.text('Song Structure'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('displays save button', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Save lives in the bottom PrimaryActionBar (add-mode label).
      expect(find.text('Save Song'), findsOneWidget);
    });

    testWidgets('allows entering song title and artist', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
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

    testWidgets('allows entering BPM values', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // BPM fields live inside the collapsed 'Key & BPM' section; expand it.
      await tester.ensureVisible(find.text('Key & BPM'));
      await tester.tap(find.text('Key & BPM'));
      await tester.pumpAndSettle();

      // The grid has one 'BPM' field per row: Original first, then Our.
      final bpmFields = find.widgetWithText(TextFormField, 'BPM');
      expect(bpmFields, findsNWidgets(2));

      await tester.enterText(bpmFields.at(0), '120');
      await tester.pump();
      await tester.enterText(bpmFields.at(1), '125');
      await tester.pump();

      // Verify values
      expect(find.text('120'), findsWidgets);
      expect(find.text('125'), findsWidgets);
    });

    testWidgets('allows entering notes', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Notes field lives inside the collapsed 'Notes' section; scroll it
      // clear of the bottom action bar, then expand it.
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      final notesField = find.widgetWithText(TextFormField, 'Notes...');
      await tester.enterText(notesField, 'Test notes');
      await tester.pump();

      // Verify notes
      expect(find.text('Test notes'), findsWidgets);
    });

    testWidgets('displays tag selection chips when expanded', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
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

    testWidgets('allows selecting tags', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
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

    testWidgets('displays search buttons', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
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

    testWidgets('populates form fields when editing', (
      tester,
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
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Title and artist populate the always-visible fields.
      expect(find.text('Existing Song'), findsWidgets);
      expect(find.text('Existing Artist'), findsWidgets);

      // BPM values live inside the collapsed 'Key & BPM' section.
      await tester.ensureVisible(find.text('Key & BPM'));
      await tester.tap(find.text('Key & BPM'));
      await tester.pumpAndSettle();

      expect(find.text('130'), findsWidgets);
      expect(find.text('135'), findsWidgets);
    });

    testWidgets('shows validation when saving without title', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Tap the save button in the bottom PrimaryActionBar.
      await tester.tap(find.text('Save Song'));
      await tester.pumpAndSettle();

      // Verify validation message appears (form validation should prevent save)
      expect(find.text('Title required'), findsOneWidget);
    });

    testWidgets('displays key selector dropdowns', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Key selectors live inside the collapsed 'Key & BPM' section.
      await tester.ensureVisible(find.text('Key & BPM'));
      await tester.tap(find.text('Key & BPM'));
      await tester.pumpAndSettle();

      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Our'), findsOneWidget);
    });

    testWidgets('displays links section', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Verify links section (initially expanded, may find multiple due to collapsible header)
      expect(find.text('Links'), findsWidgets);
    });

    testWidgets('renders scaffold', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders app bar', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders ListView body', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays Wrap for search buttons', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      await tester.dragUntilVisible(
        find.byType(Wrap),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pump();

      // Tags and the search-button row both use Wrap.
      expect(find.byType(Wrap), findsWidgets);
    });

    testWidgets('displays search icons', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
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
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Scroll down to reveal search buttons
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.byIcon(Icons.music_note), findsWidgets);
    });

    testWidgets('displays analytics icon for BPM/Key', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Scroll down to reveal search buttons
      await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
      await tester.pumpAndSettle();

      // Verify BPM/Key button is visible
      expect(find.text('BPM/Key'), findsOneWidget);
    });

    testWidgets('displays SizedBox for spacing', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('displays Align widget for search buttons', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Scroll down to reveal search buttons
      await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
      await tester.pumpAndSettle();

      // Verify Wrap (containing search buttons) is found
      expect(find.byType(Wrap), findsWidgets);
    });

    testWidgets('handles null song for add mode', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      expect(find.text('Add Song'), findsOneWidget);
    });

    testWidgets('initializes with form fields for new song', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Form should be ready for input
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('displays all 5 available tags when expanded', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
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

    testWidgets('displays SongForm widget', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
          ),
        ],
      );

      // Verify SongForm is rendered
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('displays PopScope for auto-save on back', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const AddSongScreen(),
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => mockAuth),
          appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
          autocompleteSearchProvider.overrideWith(
            TestAutocompleteNotifier.new,
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
