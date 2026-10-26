import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/services/last_practice_context.dart';
import 'package:flowgroove/widgets/dashboard_grid.dart';
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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        // Use larger screen to avoid overflow
        data: const MediaQueryData(size: Size(600, 1024)), // Tablet size
        child: ProviderScope(
          overrides: [
            lastPracticeContextProvider.overrideWith(
              (ref) async => LastPracticeContext(
                songId: 'resume',
                title: 'Resume home song',
                bpm: 112,
                updatedAt: DateTime(2026),
              ),
            ),
            firebaseAuthProvider.overrideWith((ref) => mockAuth),
            appUserProvider.overrideWith(() => TestAppUserNotifier(user)),
            songsProvider.overrideWith((ref) => Stream.value([])),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            setlistsProvider.overrideWith((ref) => Stream.value([])),
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

    testWidgets('renders home screen with dashboard grid', (tester) async {
      await pumpHomeScreen(tester, mockAuth: mockAuth);

      expect(find.byType(DashboardGrid), findsOneWidget);
      expect(find.text('Resume home song · 112 BPM'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows no greeting card or stat counters (#97)', (
      tester,
    ) async {
      final mockUser = MockDataHelper.createMockAppUser(displayName: 'John');

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.textContaining('Hello,'), findsNothing);
      expect(find.byType(StatCard), findsNothing);
      expect(find.text('My Library'), findsNothing);
    });

    testWidgets('displays quick actions section', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byType(QuickActionButton), findsNWidgets(4));
      expect(find.text('Add song'), findsOneWidget);
      expect(find.text('Add band'), findsOneWidget);
      expect(find.text('Add setlist'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
    });

    testWidgets('displays tools section', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      // 4 grid tools + the full-width Practice row (#145 rebalance).
      expect(find.byType(ToolButton), findsNWidgets(5));
      expect(find.text('Tuner'), findsOneWidget);
      expect(find.text('Metronome'), findsOneWidget);
      expect(find.text('Rehearsals'), findsOneWidget);
      expect(find.text('Recorder'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
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

    testWidgets('renders tool buttons with correct icons', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);
    });

    testWidgets('rehearsals empty state offers Sign up for demo users (#145)', (
      tester,
    ) async {
      final demoUser = AppUser(
        uid: 'demo',
        createdAt: DateTime(2024),
        accessRole: 'demo',
      );

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: demoUser);

      // No bands -> tapping Rehearsals opens the empty-state sheet.
      await tester.tap(find.text('Rehearsals'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Sign up to create a band'), findsOneWidget);
    });

    testWidgets('has responsive layout', (tester) async {
      final mockUser = MockDataHelper.createMockAppUser();

      await pumpHomeScreen(tester, mockAuth: mockAuth, user: mockUser);

      expect(find.byType(LayoutBuilder), findsWidgets);
    });
  });
}
