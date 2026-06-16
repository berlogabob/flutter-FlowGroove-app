import 'package:flowgroove/widgets/band_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('BandCard', () {
    testWidgets('renders band card with name', (tester) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Test Band', memberCount: 4),
      );

      expect(findText('Test Band'), findsOneWidget);
    });

    testWidgets('renders groups icon', (tester) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Test Band', memberCount: 4),
      );

      expect(findIcon(Icons.groups), findsOneWidget);
    });

    testWidgets('renders member count', (tester) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Test Band', memberCount: 4),
      );

      expect(find.text('4 members'), findsOneWidget);
    });

    testWidgets('renders member count singular for one member', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Solo Band', memberCount: 1),
      );

      expect(find.text('1 member'), findsOneWidget);
    });

    testWidgets('renders description when provided', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
          description: 'A rock band from NYC',
        ),
      );

      expect(find.text('A rock band from NYC'), findsOneWidget);
    });

    testWidgets('does not render description when null', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
        ),
      );

      verifyNotFound(find.text('A rock band from NYC'));
    });

    testWidgets('does not render description when empty', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
          description: '',
        ),
      );

      verifyNotFound(find.text(''));
    });

    testWidgets('renders edit button', (tester) async {
      await pumpAppWidget(
        tester,
        const BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
          onEdit: wasCalled,
        ),
      );

      expect(findIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('renders delete button', (tester) async {
      await pumpAppWidget(
        tester,
        const BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
          onDelete: wasCalled,
        ),
      );

      expect(findIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('does not render edit button when onEdit is null', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Test Band', memberCount: 4),
      );

      verifyNotFound(findIcon(Icons.edit));
    });

    testWidgets('does not render delete button when onDelete is null', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Test Band', memberCount: 4),
      );

      verifyNotFound(findIcon(Icons.delete));
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
          onTap: () => wasTapped = true,
        ),
      );

      await tester.tap(find.text('Test Band'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('calls onEdit when edit button is tapped', (
      tester,
    ) async {
      bool wasEdited = false;

      await pumpAppWidget(
        tester,
        BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
          onEdit: () => wasEdited = true,
        ),
      );

      await tester.tap(findIcon(Icons.edit));
      await tester.pump();

      expect(wasEdited, isTrue);
    });

    testWidgets('calls onDelete when delete button is tapped', (
      tester,
    ) async {
      bool wasDeleted = false;

      await pumpAppWidget(
        tester,
        BandCard(
          id: 'test-band',
          name: 'Test Band',
          memberCount: 4,
          onDelete: () => wasDeleted = true,
        ),
      );

      await tester.tap(findIcon(Icons.delete));
      await tester.pump();

      expect(wasDeleted, isTrue);
    });

    testWidgets('renders as Card widget', (tester) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Test Band', memberCount: 4),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (tester) async {
      await pumpAppWidget(
        tester,
        const BandCard(id: 'test-band', name: 'Test Band', memberCount: 4),
      );

      expect(find.byType(ListTile), findsOneWidget);
    });
  });

  group('CompactBandCard', () {
    testWidgets('renders compact card with name', (tester) async {
      await pumpAppWidget(
        tester,
        const CompactBandCard(id: 'test-band', name: 'Compact Band'),
      );

      expect(findText('Compact Band'), findsOneWidget);
    });

    testWidgets('renders groups icon', (tester) async {
      await pumpAppWidget(
        tester,
        const CompactBandCard(id: 'test-band', name: 'Compact Band'),
      );

      expect(findIcon(Icons.groups), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool wasTapped = false;

      await pumpAppWidget(
        tester,
        CompactBandCard(
          id: 'test-band',
          name: 'Compact Band',
          onTap: () => wasTapped = true,
        ),
      );

      await tester.tap(find.text('Compact Band'));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('renders as Card widget', (tester) async {
      await pumpAppWidget(
        tester,
        const CompactBandCard(id: 'test-band', name: 'Compact Band'),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders as ListTile', (tester) async {
      await pumpAppWidget(
        tester,
        const CompactBandCard(id: 'test-band', name: 'Compact Band'),
      );

      expect(find.byType(ListTile), findsOneWidget);
    });
  });
}

void wasCalled() {}
