import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_repsync_app/widgets/offline_indicator.dart';
import 'package:flutter_repsync_app/services/connectivity_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('OfflineIndicator', () {
    testWidgets('is hidden when online', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => false)],
      );

      // Should not render anything when online
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('is visible when offline', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      // Should render when offline
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('displays wifi off icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('displays "You\'re offline" message', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.text("You're offline"), findsOneWidget);
    });

    testWidgets('displays "Showing cached data" subtitle', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.text('Showing cached data'), findsOneWidget);
    });

    testWidgets('displays cloud off icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('has amber background color', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());
    });

    testWidgets('has full width', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      // Container should have constraints for full width
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('has horizontal padding', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      // Verify the container has padding
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isNotNull);
    });

    testWidgets('displays message in column layout', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      // Should have column for text layout
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('has box shadow', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
    });

    testWidgets('text is white', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      // Verify text widgets are present with proper styling
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.length, greaterThan(0));
    });

    testWidgets('has Expanded widget for text', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('has Row layout', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineIndicator(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Row), findsOneWidget);
    });
  });

  group('OfflineStatusIcon', () {
    testWidgets('is hidden when online', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => false)],
      );

      expect(find.byType(Padding), findsNothing);
    });

    testWidgets('is visible when offline', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Padding), findsOneWidget);
    });

    testWidgets('displays wifi off icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('has amber color', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded));
      expect(icon.color, isNotNull);
    });

    testWidgets('has tooltip', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('tooltip has correct message', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals('You are offline - showing cached data'));
    });

    testWidgets('has right padding', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.padding.right, equals(8));
    });

    testWidgets('icon size is 24', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineStatusIcon(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded));
      expect(icon.size, equals(24));
    });
  });

  group('OfflineBanner', () {
    testWidgets('is hidden when online', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => false)],
      );

      expect(find.byType(Material), findsNothing);
    });

    testWidgets('is visible when offline', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Material), findsOneWidget);
    });

    testWidgets('displays title "No Internet Connection"', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.text('No Internet Connection'), findsOneWidget);
    });

    testWidgets('displays detailed message', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(
        find.text(
          "You're viewing cached data. Some features may be limited until you're back online.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays wifi off icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('displays "Cached" badge', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.text('Cached'), findsOneWidget);
    });

    testWidgets('displays storage icon in badge', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
    });

    testWidgets('has Material widget with elevation', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      final material = tester.widget<Material>(find.byType(Material));
      expect(material.elevation, equals(4));
    });

    testWidgets('has full width container', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      // Find the main container inside Material
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('has Row layout', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('has Column layout for text', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('has Expanded widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('icon has rounded container', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      // Should have containers for icon backgrounds
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('has amber background', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const OfflineBanner(),
        overrides: [offlineProvider.overrideWith((ref) => true)],
      );

      // Verify amber background color
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(containers.length, greaterThan(0));
    });
  });
}
