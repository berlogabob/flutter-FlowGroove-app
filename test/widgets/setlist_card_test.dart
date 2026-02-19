import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/setlist_card.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('SetlistCard', () {
    testWidgets('renders setlist card with name', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
        ),
      );

      expect(findText('Test Setlist'), findsOneWidget);
    });

    testWidgets('renders playlist icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
        ),
      );

      expect(findIcon(Icons.playlist_play), findsOneWidget);
    });

    testWidgets('renders song count', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
        ),
      );

      expect(find.text('10 songs'), findsOneWidget);
    });

    testWidgets('renders song count singular for one song', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 1,
        ),
      );

      expect(find.text('1 song'), findsOneWidget);
    });

    testWidgets('renders band name when provided', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          bandName: 'Test Band',
        ),
      );

      expect(find.text('Test Band'), findsOneWidget);
    });

    testWidgets('does not render band name when null', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          bandName: null,
        ),
      );

      verifyNotFound(find.text('Test Band'));
    });

    testWidgets('does not render band name when empty', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          bandName: '',
        ),
      );

      verifyNotFound(find.text(''));
    });

    testWidgets('renders date when provided', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          date: '2024-06-15',
        ),
      );

      expect(find.text('Jun 15, 2024'), findsOneWidget);
    });

    testWidgets('does not render date when null', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          date: null,
        ),
      );

      verifyNotFound(find.text('Jun 15, 2024'));
    });

    testWidgets('renders edit button', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          onEdit: wasCalled,
        ),
      );

      expect(findIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('renders delete button', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          onDelete: wasCalled,
        ),
      );

      expect(findIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('does not render edit button when onEdit is null', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
        ),
      );

      verifyNotFound(findIcon(Icons.edit));
    });

    testWidgets('does not render delete button when onDelete is null', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
        ),
      );

      verifyNotFound(findIcon(Icons.delete));
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          onTap: () => wasTapped = true,
        ),
      );

      await tester.tap(find.text('Test Setlist'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('calls onEdit when edit button is tapped', (
      WidgetTester tester,
    ) async {
      bool wasEdited = false;

      await pumpAppWidget(
        tester,
        SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          onEdit: () => wasEdited = true,
        ),
      );

      await tester.tap(findIcon(Icons.edit));
      await tester.pump();

      expect(wasEdited, isTrue);
    });

    testWidgets('calls onDelete when delete button is tapped', (
      WidgetTester tester,
    ) async {
      bool wasDeleted = false;

      await pumpAppWidget(
        tester,
        SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          onDelete: () => wasDeleted = true,
        ),
      );

      await tester.tap(findIcon(Icons.delete));
      await tester.pump();

      expect(wasDeleted, isTrue);
    });

    testWidgets('renders as Card widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('formats date correctly', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          date: '2024-01-01',
        ),
      );

      expect(find.text('Jan 1, 2024'), findsOneWidget);
    });

    testWidgets('handles invalid date gracefully', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SetlistCard(
          id: 'test-setlist',
          name: 'Test Setlist',
          songCount: 10,
          date: 'invalid-date',
        ),
      );

      expect(find.text('invalid-date'), findsOneWidget);
    });
  });

  group('CompactSetlistCard', () {
    testWidgets('renders compact card with name', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const CompactSetlistCard(
          id: 'test-setlist',
          name: 'Compact Setlist',
          songCount: 5,
        ),
      );

      expect(findText('Compact Setlist'), findsOneWidget);
    });

    testWidgets('renders song count', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const CompactSetlistCard(
          id: 'test-setlist',
          name: 'Compact Setlist',
          songCount: 5,
        ),
      );

      expect(find.text('5 songs'), findsOneWidget);
    });

    testWidgets('renders playlist icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const CompactSetlistCard(
          id: 'test-setlist',
          name: 'Compact Setlist',
          songCount: 5,
        ),
      );

      expect(findIcon(Icons.playlist_play), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        CompactSetlistCard(
          id: 'test-setlist',
          name: 'Compact Setlist',
          songCount: 5,
          onTap: () => wasTapped = true,
        ),
      );

      await tester.tap(find.text('Compact Setlist'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('renders as Card widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const CompactSetlistCard(
          id: 'test-setlist',
          name: 'Compact Setlist',
          songCount: 5,
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const CompactSetlistCard(
          id: 'test-setlist',
          name: 'Compact Setlist',
          songCount: 5,
        ),
      );

      expect(find.byType(ListTile), findsOneWidget);
    });
  });
}

void wasCalled() {}
