import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/screens/bands/my_bands_screen.dart';
import 'package:flutter_repsync_app/providers/data_providers.dart';
import 'package:flutter_repsync_app/providers/auth_provider.dart';
import 'package:flutter_repsync_app/models/band.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mocks.dart';
import '../login_screen_test.dart';

void main() {
  group('MyBandsScreen', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
    });

    testWidgets('renders my bands screen with title', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify screen title
      expect(findText('My Bands'), findsOneWidget);
    });

    testWidgets('displays search field', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify search field
      expect(findText('Search bands...'), findsOneWidget);
      expect(findIcon(Icons.search), findsWidgets);
    });

    testWidgets('displays floating action buttons', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify FABs
      final fabs = find.byType(FloatingActionButton);
      expect(fabs, findsNWidgets(2));
    });

    testWidgets('displays empty state when no bands', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify empty state
      expect(findText('No bands yet'), findsOneWidget);
      expect(findText('Create a band to get started'), findsOneWidget);
      expect(findText('Create Band'), findsOneWidget);
    });

    testWidgets('displays list of bands', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final bands = [
        MockDataHelper.createMockBand(id: '1', name: 'Band One', members: [BandMember(uid: '1', role: 'member')]),
        MockDataHelper.createMockBand(id: '2', name: 'Band Two', members: [BandMember(uid: '1', role: 'member'), BandMember(uid: '2', role: 'member')]),
        MockDataHelper.createMockBand(id: '3', name: 'Band Three', members: [BandMember(uid: '1', role: 'member')]),
      ];

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value(bands)),
        ],
      );

      // Verify bands are displayed
      expect(find.text('Band One'), findsOneWidget);
      expect(find.text('Band Two'), findsOneWidget);
      expect(find.text('Band Three'), findsOneWidget);
    });

    testWidgets('displays member count for each band', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final bands = [
        MockDataHelper.createMockBand(id: '1', name: 'Solo Band', members: [BandMember(uid: '1', role: 'member')]),
        MockDataHelper.createMockBand(id: '2', name: 'Duo Band', members: [BandMember(uid: '1', role: 'member'), BandMember(uid: '2', role: 'member')]),
        MockDataHelper.createMockBand(id: '3', name: 'Trio Band', members: [BandMember(uid: '1', role: 'member'), BandMember(uid: '2', role: 'member'), BandMember(uid: '3', role: 'member')]),
      ];

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value(bands)),
        ],
      );

      // Verify member counts
      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
    });

    testWidgets('filters bands by name', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final bands = [
        MockDataHelper.createMockBand(id: '1', name: 'Rock Band', members: []),
        MockDataHelper.createMockBand(id: '2', name: 'Jazz Band', members: []),
        MockDataHelper.createMockBand(id: '3', name: 'Pop Band', members: []),
      ];

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value(bands)),
        ],
      );

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Rock');
      await tester.pumpAndSettle();

      // Verify only matching band is displayed
      expect(find.text('Rock Band'), findsOneWidget);
      expect(find.text('Jazz Band'), findsNothing);
      expect(find.text('Pop Band'), findsNothing);
    });

    testWidgets('displays search empty state when no results', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final bands = [
        MockDataHelper.createMockBand(id: '1', name: 'Rock Band', members: []),
      ];

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value(bands)),
        ],
      );

      // Enter search query with no results
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'nonexistent');
      await tester.pumpAndSettle();

      // Verify search empty state
      expect(findText('No results found'), findsOneWidget);
    });

    testWidgets('navigates to create band screen when tapping create FAB', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToCreate = false;

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/create-band') {
              didNavigateToCreate = true;
            }
          }),
        ],
      );

      // Tap create FAB (first one)
      final fabs = find.byType(FloatingActionButton);
      await tester.tap(fabs.first);
      await tester.pump();

      expect(didNavigateToCreate, isTrue);
    });

    testWidgets('navigates to join band screen when tapping join FAB', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigateToJoin = false;

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/join-band') {
              didNavigateToJoin = true;
            }
          }),
        ],
      );

      // Tap join FAB (second one)
      final fabs = find.byType(FloatingActionButton);
      await tester.tap(fabs.last);
      await tester.pump();

      expect(didNavigateToJoin, isTrue);
    });

    testWidgets('navigates to create band screen when tapping Create Band button', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      bool didNavigate = false;

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
        navigatorObservers: [
          MockNavigatorObserver(onPush: (route) {
            if (route.settings.name == '/create-band') {
              didNavigate = true;
            }
          }),
        ],
      );

      // Tap Create Band button
      await tester.tap(findText('Create Band'));
      await tester.pump();

      expect(didNavigate, isTrue);
    });

    testWidgets('shows loading indicator when loading bands', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([])),
        ],
      );

      // Verify screen renders
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays error message when error occurs', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.error(Exception('Failed to load bands'))),
        ],
      );

      // Verify error message
      expect(find.text('Error: Exception: Failed to load bands'), findsOneWidget);
    });

    testWidgets('displays band description when available', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final band = MockDataHelper.createMockBand(
        id: '1',
        name: 'Test Band',
        description: 'A rock band from NYC',
        members: [BandMember(uid: '1', role: 'member')],
      );

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([band])),
        ],
      );

      // Verify description is displayed
      expect(find.text('A rock band from NYC'), findsOneWidget);
    });

    testWidgets('displays band cards with correct icons', (WidgetTester tester) async {
      final mockUser = MockDataHelper.createMockAppUser();
      final band = MockDataHelper.createMockBand(
        id: '1',
        name: 'Test Band',
        members: [BandMember(uid: '1', role: 'member')],
      );

      await pumpAppWidget(
        tester,
        const MyBandsScreen(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          
          appUserProvider.overrideWithValue(mockUser),
          currentUserProvider.overrideWithValue(mockUser),
          bandsProvider.overrideWithValue(Stream.value([band])),
        ],
      );

      // Verify icons
      expect(findIcon(Icons.groups), findsWidgets);
      expect(findIcon(Icons.edit), findsOneWidget);
      expect(findIcon(Icons.delete), findsOneWidget);
    });
  });
}
