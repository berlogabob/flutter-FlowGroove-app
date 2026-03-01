import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/song_attribution_badge.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SongAttributionBadge', () {
    testWidgets('renders nothing when all badges are hidden', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(
          showOriginalOwner: false,
          showContributor: false,
          showCopyIndicator: false,
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders copy badge when isCopy is true', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(tester, const SongAttributionBadge(isCopy: true));

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.text('Shared'), findsWidgets);
    });

    testWidgets('does not render copy badge when isCopy is false', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(tester, const SongAttributionBadge(isCopy: false));

      expect(find.byIcon(Icons.content_copy), findsNothing);
    });

    testWidgets('renders original owner badge', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(
          originalOwnerName: 'John Doe',
          showOriginalOwner: true,
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.textContaining('by John Doe'), findsWidgets);
    });

    testWidgets('does not render original owner when name is null', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(originalOwnerName: null),
      );

      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('renders contributor badge when isCopy is true', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(
          contributorName: 'Jane Doe',
          isCopy: true,
          showContributor: true,
        ),
      );

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.textContaining('added by Jane Doe'), findsWidgets);
    });

    testWidgets('does not render contributor when isCopy is false', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(contributorName: 'Jane Doe', isCopy: false),
      );

      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    });

    testWidgets('respects showOriginalOwner flag', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(
          originalOwnerName: 'John Doe',
          showOriginalOwner: false,
        ),
      );

      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('respects showContributor flag', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(
          contributorName: 'Jane Doe',
          isCopy: true,
          showContributor: false,
        ),
      );

      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    });

    testWidgets('respects showCopyIndicator flag', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(isCopy: true, showCopyIndicator: false),
      );

      expect(find.byIcon(Icons.content_copy), findsNothing);
    });

    testWidgets('renders with small size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(isCopy: true, size: BadgeSize.small),
      );

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('renders with medium size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(isCopy: true, size: BadgeSize.medium),
      );

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.text('Shared'), findsOneWidget);
    });

    testWidgets('renders with large size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const SongAttributionBadge(isCopy: true, size: BadgeSize.large),
      );

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.text('Shared'), findsOneWidget);
    });

    testWidgets('uses Wrap for layout', (WidgetTester tester) async {
      await pumpAppWidget(tester, const SongAttributionBadge(isCopy: true));

      expect(find.byType(Wrap), findsOneWidget);
    });
  });

  group('CompactAttributionBadge', () {
    testWidgets('renders nothing when isCopy is false', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(tester, const CompactAttributionBadge(isCopy: false));

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders copy badge when isCopy is true', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(tester, const CompactAttributionBadge(isCopy: true));

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('shows contributor name when provided', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const CompactAttributionBadge(isCopy: true, contributorName: 'Jane'),
      );

      expect(find.textContaining('by Jane'), findsOneWidget);
    });

    testWidgets('hides contributor name when null', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const CompactAttributionBadge(isCopy: true, contributorName: null),
      );

      expect(find.textContaining('by'), findsNothing);
    });
  });

  group('AttributionSubtitle', () {
    testWidgets('renders subtitle text', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AttributionSubtitle(subtitle: 'Test Artist'),
      );

      expect(find.text('Test Artist'), findsOneWidget);
    });

    testWidgets('renders attribution badge', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AttributionSubtitle(
          subtitle: 'Test Artist',
          isCopy: true,
          contributorName: 'Jane',
        ),
      );

      expect(find.byType(SongAttributionBadge), findsOneWidget);
    });

    testWidgets('uses Column layout', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AttributionSubtitle(subtitle: 'Test Artist'),
      );

      expect(find.byType(Column), findsOneWidget);
    });
  });
}
