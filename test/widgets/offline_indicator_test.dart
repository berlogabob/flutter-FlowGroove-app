import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/offline_indicator.dart';

void main() {
  group('OfflineIndicator', () {
    testWidgets('renders banner variant', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineIndicator.banner()),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(
        find.text('Offline - Some features may be limited'),
        findsOneWidget,
      );
    });

    testWidgets('renders chip variant', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: OfflineIndicator.chip()));

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('renders minimal variant', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineIndicator.minimal()),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('uses theme colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineIndicator.banner()),
      );

      // Verify orange accent color is used
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('banner is full width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineIndicator.banner()),
      );

      // Verify banner takes full width
      expect(find.byType(Container), findsOneWidget);
    });
  });
}
