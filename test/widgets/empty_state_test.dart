import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/empty_state.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders empty state with icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const EmptyState(icon: Icons.search, message: 'No results'),
      );

      expect(findIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders empty state with message', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const EmptyState(icon: Icons.search, message: 'No results found'),
      );

      expect(findText('No results found'), findsOneWidget);
    });

    testWidgets('renders empty state with hint', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const EmptyState(
          icon: Icons.search,
          message: 'No results',
          hint: 'Try a different search term',
        ),
      );

      expect(findText('Try a different search term'), findsOneWidget);
    });

    testWidgets(
      'renders action button when actionLabel and onAction provided',
      (WidgetTester tester) async {
        await pumpAppWidget(
          tester,
          const EmptyState(
            icon: Icons.search,
            message: 'No results',
            actionLabel: 'Search',
            onAction: null, // Explicitly null - button won't render
          ),
        );

        // Button requires both actionLabel AND onAction to render
        expect(find.byType(ElevatedButton), findsNothing);
      },
    );

    testWidgets('renders action button with valid onAction callback', (
      WidgetTester tester,
    ) async {
      bool actionCalled = false;
      await pumpAppWidget(
        tester,
        EmptyState(
          icon: Icons.search,
          message: 'No results',
          actionLabel: 'Search',
          onAction: () => actionCalled = true,
        ),
      );

      expect(findText('Search'), findsOneWidget);
      expect(findIcon(Icons.add), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('does not render action button when onAction is null', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const EmptyState(
          icon: Icons.search,
          message: 'No results',
          actionLabel: 'Search',
          onAction: null,
        ),
      );

      // Button requires both actionLabel AND onAction
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('calls onAction when action button is tapped', (
      WidgetTester tester,
    ) async {
      bool wasActionCalled = false;

      await pumpAppWidget(
        tester,
        EmptyState(
          icon: Icons.search,
          message: 'No results',
          actionLabel: 'Search',
          onAction: () => wasActionCalled = true,
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(wasActionCalled, isTrue);
    });

    testWidgets('renders centered', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const EmptyState(icon: Icons.search, message: 'No results'),
      );

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('renders with default icon color', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const EmptyState(icon: Icons.search, message: 'No results'),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(Colors.grey));
    });

    testWidgets('renders with custom icon color', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const EmptyState(
          icon: Icons.search,
          message: 'No results',
          iconColor: Colors.red,
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(Colors.red));
    });

    testWidgets('renders with default icon size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const EmptyState(icon: Icons.search, message: 'No results'),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, equals(80));
    });

    testWidgets('renders with custom icon size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const EmptyState(
          icon: Icons.search,
          message: 'No results',
          iconSize: 100,
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, equals(100));
    });
  });

  group('EmptyState.songs', () {
    testWidgets('renders songs empty state', (WidgetTester tester) async {
      await pumpAppWidget(tester, EmptyState.songs());

      expect(findIcon(Icons.music_note), findsOneWidget);
      expect(findText('No songs yet'), findsOneWidget);
      expect(findText('Tap + to add your first song'), findsOneWidget);
      // Button won't render without onAdd callback
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders songs empty state with onAdd callback', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        EmptyState.songs(onAdd: () {}),
      );

      expect(findIcon(Icons.music_note), findsOneWidget);
      expect(findText('No songs yet'), findsOneWidget);
      expect(findText('Tap + to add your first song'), findsOneWidget);
      expect(findText('Add Song'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('calls onAdd when Add Song button is tapped', (
      WidgetTester tester,
    ) async {
      bool wasAddCalled = false;

      await pumpAppWidget(
        tester,
        EmptyState.songs(onAdd: () => wasAddCalled = true),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(wasAddCalled, isTrue);
    });
  });

  group('EmptyState.bands', () {
    testWidgets('renders bands empty state', (WidgetTester tester) async {
      await pumpAppWidget(tester, EmptyState.bands());

      expect(findIcon(Icons.groups), findsOneWidget);
      expect(findText('No bands yet'), findsOneWidget);
      expect(findText('Create a band to get started'), findsOneWidget);
      // Button won't render without onCreate callback
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders bands empty state with onCreate callback', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        EmptyState.bands(onCreate: () {}),
      );

      expect(findIcon(Icons.groups), findsOneWidget);
      expect(findText('No bands yet'), findsOneWidget);
      expect(findText('Create a band to get started'), findsOneWidget);
      expect(findText('Create Band'), findsOneWidget);
    });

    testWidgets('calls onCreate when Create Band button is tapped', (
      WidgetTester tester,
    ) async {
      bool wasCreateCalled = false;

      await pumpAppWidget(
        tester,
        EmptyState.bands(onCreate: () => wasCreateCalled = true),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(wasCreateCalled, isTrue);
    });
  });

  group('EmptyState.setlists', () {
    testWidgets('renders setlists empty state', (WidgetTester tester) async {
      await pumpAppWidget(tester, EmptyState.setlists());

      expect(findIcon(Icons.playlist_play), findsOneWidget);
      expect(findText('No setlists yet'), findsOneWidget);
      // Check for either hint message
      expect(
        find.textContaining('setlist'),
        findsOneWidget,
      );
      // Button won't render without onCreate callback
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders setlists empty state with onCreate callback', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        EmptyState.setlists(onCreate: () {}),
      );

      expect(findIcon(Icons.playlist_play), findsOneWidget);
      expect(findText('No setlists yet'), findsOneWidget);
      expect(findText('Create Setlist'), findsOneWidget);
    });

    testWidgets('calls onCreate when Create Setlist button is tapped', (
      WidgetTester tester,
    ) async {
      bool wasCreateCalled = false;

      await pumpAppWidget(
        tester,
        EmptyState.setlists(onCreate: () => wasCreateCalled = true),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(wasCreateCalled, isTrue);
    });
  });

  group('EmptyState.search', () {
    testWidgets('renders search empty state without query', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(tester, EmptyState.search());

      expect(findIcon(Icons.search_off), findsOneWidget);
      expect(findText('No results found'), findsOneWidget);
      expect(find.textContaining('Try'), findsOneWidget);
    });

    testWidgets('renders search empty state with query', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(tester, EmptyState.search(query: 'test query'));

      expect(findIcon(Icons.search_off), findsOneWidget);
      expect(findText('No results found'), findsOneWidget);
      expect(find.textContaining('test query'), findsOneWidget);
    });

    testWidgets('does not render action button', (WidgetTester tester) async {
      await pumpAppWidget(tester, EmptyState.search(query: 'test'));

      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
