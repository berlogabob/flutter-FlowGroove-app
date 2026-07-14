import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mocks.dart';
import '../../helpers/routed_test_harness.dart';

void main() {
  group('MyBandsScreen', () {
    late AppUser mockUser;

    List<dynamic> overridesFor(Stream<List<Band>> bands) => [
      appUserProvider.overrideWith(() => TestAppUserNotifier(mockUser)),
      bandsProvider.overrideWith((ref) => bands),
    ];

    setUp(() {
      mockUser = MockDataHelper.createMockAppUser();
    });

    testWidgets('renders my bands screen with title and search', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value([])),
      );

      expect(find.text('Search bands...'), findsOneWidget);
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('displays one create floating action button', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value([])),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip('Create band'), findsOneWidget);
      expect(find.byIcon(Icons.group_add), findsOneWidget);
    });

    testWidgets('displays empty state when no bands exist', (tester) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value([])),
      );

      expect(find.text('No bands yet'), findsOneWidget);
      expect(find.text('Create a band to get started'), findsOneWidget);
      expect(find.text('Create Band'), findsOneWidget);
      expect(find.text('Join band'), findsOneWidget);
    });

    testWidgets('displays list of bands with descriptions and member counts', (
      tester,
    ) async {
      final bands = [
        MockDataHelper.createMockBand(
          id: '1',
          name: 'Jazz Quartet',
          description: 'Smooth jazz ensemble',
          members: [
            BandMember(uid: 'u1', role: BandMember.roleAdmin),
            BandMember(uid: 'u2', role: BandMember.roleViewer),
          ],
        ),
        MockDataHelper.createMockBand(
          id: '2',
          name: 'Rock Band',
          description: 'Classic rock covers',
          members: [BandMember(uid: 'u1', role: BandMember.roleAdmin)],
        ),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value(bands)),
      );

      expect(find.text('Jazz Quartet'), findsOneWidget);
      expect(find.text('Rock Band'), findsOneWidget);
      expect(find.text('Smooth jazz ensemble'), findsOneWidget);
      expect(find.text('Classic rock covers'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);
      expect(find.byIcon(Icons.groups), findsWidgets);
    });

    testWidgets('filters bands by name', (tester) async {
      final bands = [
        MockDataHelper.createMockBand(id: '1', name: 'Jazz Quartet'),
        MockDataHelper.createMockBand(id: '2', name: 'Rock Band'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value(bands)),
      );

      await tester.enterText(find.byType(TextField), 'Jazz');
      await tester.pump();

      expect(find.text('Jazz Quartet'), findsOneWidget);
      expect(find.text('Rock Band'), findsNothing);
    });

    testWidgets('displays search empty state when no results match', (
      tester,
    ) async {
      final bands = [
        MockDataHelper.createMockBand(id: '1', name: 'Jazz Quartet'),
      ];

      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value(bands)),
      );

      await tester.enterText(find.byType(TextField), 'metal');
      await tester.pump();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Try searching for "metal"'), findsOneWidget);
    });

    testWidgets('navigates to create band from create FAB', (tester) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value([])),
      );

      await tester.tap(find.byTooltip('Create band'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/bands/create');
      expect(find.text('route:create-band'), findsOneWidget);
    });

    testWidgets('navigates to join band from empty state CTA', (tester) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value([])),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Join band'));
      await tester.pumpAndSettle();

      // join-band is a pushed route: the reported URI goes stale; the
      // rendered marker is the navigation signal.
      expect(find.text('route:join-band'), findsOneWidget);
    });

    testWidgets('navigates to join band from the screen menu', (tester) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(
          Stream<List<Band>>.value([
            MockDataHelper.createMockBand(id: '1', name: 'Jazz Quartet'),
          ]),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join band'));
      await tester.pumpAndSettle();

      // join-band is a pushed route: the reported URI goes stale; the
      // rendered marker is the navigation signal.
      expect(find.text('route:join-band'), findsOneWidget);
    });

    testWidgets('navigates to create band from empty state CTA', (
      tester,
    ) async {
      final router = await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(Stream<List<Band>>.value([])),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Band'));
      await tester.pumpAndSettle();

      expect(currentRouterUri(router).path, '/main/bands/create');
      expect(find.text('route:create-band'), findsOneWidget);
    });

    testWidgets('shows loading indicator while bands are loading', (
      tester,
    ) async {
      await pumpRoutedTestApp(
        tester,
        initialLocation: '/main/bands',
        overrides: overridesFor(const Stream<List<Band>>.empty()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

  });
}
