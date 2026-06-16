import 'package:flowgroove/models/setlist.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mocks.dart';
import '../../helpers/routed_test_harness.dart';

void main() {
  group('SetlistsListScreen', () {
    late AppUser mockUser;

    List<dynamic> overridesFor({
      required Stream<List<Setlist>> setlists,
      Stream<List<Song>>? songs,
    }) => [
      appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
      setlistsProvider.overrideWith((ref) => setlists),
      songsProvider.overrideWith(
        (ref) => songs ?? Stream<List<Song>>.value([]),
      ),
    ];

    setUp(() {
      mockUser = MockDataHelper.createMockAppUser();
    });

    testWidgets('renders setlists screen with title and search', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      expect(find.text('Setlists'), findsOneWidget);
      expect(find.text('Search setlists...'), findsOneWidget);
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('displays empty state when no setlists exist', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      expect(find.text('No setlists yet'), findsOneWidget);
      expect(find.text('Create a setlist for your next gig'), findsOneWidget);
      expect(find.text('Create Setlist'), findsOneWidget);
    });

    testWidgets('displays setlist cards with song counts and event dates', (
      tester,
    ) async {
      final setlists = [
        MockDataHelper.createMockSetlist(
          id: '1',
          name: 'Gig Setlist',
          songIds: ['s1', 's2', 's3'],
          eventDateTime: DateTime(2026, 5, 10),
        ),
        MockDataHelper.createMockSetlist(
          id: '2',
          name: 'Practice Setlist',
          songIds: ['s1'],
        ),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream<List<Setlist>>.value(setlists),
        ),
      );

      expect(find.text('Gig Setlist'), findsOneWidget);
      expect(find.text('Practice Setlist'), findsOneWidget);
      expect(find.text('3 songs'), findsOneWidget);
      expect(find.text('1 song'), findsOneWidget);
      expect(find.text('10.05.2026'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play), findsWidgets);
    });

    testWidgets('filters setlists by name', (tester) async {
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Gig Setlist'),
        MockDataHelper.createMockSetlist(id: '2', name: 'Practice Setlist'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream<List<Setlist>>.value(setlists),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Gig');
      await tester.pump();

      expect(find.text('Gig Setlist'), findsOneWidget);
      expect(find.text('Practice Setlist'), findsNothing);
    });

    testWidgets('shows search empty state when no setlists match', (
      tester,
    ) async {
      final setlists = [
        MockDataHelper.createMockSetlist(id: '1', name: 'Gig Setlist'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(
          setlists: Stream<List<Setlist>>.value(setlists),
        ),
      );

      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Try searching for "missing"'), findsOneWidget);
    });

    testWidgets('navigates to create setlist from FAB', (tester) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/setlists/create');
      expect(find.text('route:create-setlist'), findsOneWidget);
    });

    testWidgets('navigates to create setlist from empty state CTA', (
      tester,
    ) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: Stream<List<Setlist>>.value([])),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Setlist'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/setlists/create');
      expect(find.text('route:create-setlist'), findsOneWidget);
    });

    testWidgets('shows loading indicator while setlists are loading', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/setlists',
        overrides: overridesFor(setlists: const Stream<List<Setlist>>.empty()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

  });
}
