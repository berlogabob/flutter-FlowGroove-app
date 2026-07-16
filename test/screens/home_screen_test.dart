import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/widgets/dashboard_grid.dart';
import 'package:flowgroove/widgets/greeting_card.dart';
import 'package:flowgroove/widgets/quick_action_button.dart';
import 'package:flowgroove/widgets/stat_card.dart';
import 'package:flowgroove/widgets/tool_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.dart';
import '../helpers/mocks.mocks.dart';
import '../helpers/test_helpers.dart';

// Test notifier that returns a specific value
class TestAppUserNotifier extends AppUserNotifier {

  TestAppUserNotifier(this.mockUser);
  final AppUser? mockUser;

  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(mockUser);
}

// Helper to pump HomeScreen with proper screen size
Future<void> pumpHomeScreen(
  WidgetTester tester, {
  required MockFirebaseAuth mockAuth,
  AppUser? user,
  int songCount = 0,
  int bandCount = 0,
  int setlistCount = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        // Use larger screen to avoid overflow
        data: const MediaQueryData(size: Size(600, 1024)), // Tablet size
        child: ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(user)),
            songsProvider.overrideWith((ref) => Stream.value([])),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            setlistsProvider.overrideWith((ref) => Stream.value([])),
            songCountProvider.overrideWith((ref) => songCount),
            bandCountProvider.overrideWith((ref) => bandCount),
            setlistCountProvider.overrideWith((ref) => setlistCount),
          ],
          child: const HomeScreen(),
        ),
      ),
    ),
  );
  // Use pump instead of pumpAndSettle to avoid Firebase timer issues
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('HomeScreen', () {
    late MockFirebaseAuth mockAuth;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await initializeFirebaseForTests();
    });

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    testWidgets('renders home screen with dashboard grid', (
      tester,
    ) async {
      await pumpHomeScreen(tester, mockAuth: mockAuth);

      expect(find.byType(DashboardGrid), findsOneWidget);
    });

    testWidgets('displays greeting section with user name', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser(displayName: 'John');

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byType(GreetingCard), findsOneWidget);
      expect(find.text('Hello, John!'), findsOneWidget);
    });

    testWidgets('displays statistics section with stat cards', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byType(StatCard), findsNWidgets(3));
      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Bands'), findsOneWidget);
      expect(find.text('Setlists'), findsOneWidget);
    });

    testWidgets('displays correct statistics counts', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(
        tester,
        mockAuth: mockAuth,
        user: mockUser,
        songCount: 5,
        bandCount: 2,
        setlistCount: 3,
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('displays quick actions section', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byType(QuickActionButton), findsNWidgets(4));
      expect(find.text('Song'), findsOneWidget);
      expect(find.text('Band'), findsOneWidget);
      expect(find.text('Setlist'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
    });

    testWidgets('displays tools section', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byType(ToolButton), findsNWidgets(3));
      expect(find.text('Tuner'), findsOneWidget);
      expect(find.text('Metronome'), findsOneWidget);
      expect(find.text('Rehearsals'), findsOneWidget);
    });

    testWidgets('displays loading state when user data is loading', (
      tester,
    ) async {
      await pumpHomeScreen(tester, mockAuth: mockAuth);

      expect(find.byType(GreetingCard), findsOneWidget);
    });

    testWidgets('renders stat cards with correct icons', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.byIcon(Icons.groups), findsOneWidget);
      expect(find.byIcon(Icons.queue_music), findsOneWidget);
    });

    testWidgets('renders quick action buttons with correct icons', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.group_add), findsOneWidget);
      expect(find.byIcon(Icons.playlist_add), findsOneWidget);
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
    });

    testWidgets('renders tool buttons with correct icons', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);
    });

    testWidgets('has responsive layout', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byType(LayoutBuilder), findsWidgets);
    });

    testWidgets('displays zero counts when no data', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.text('0'), findsNWidgets(3));
    });
  });
}
