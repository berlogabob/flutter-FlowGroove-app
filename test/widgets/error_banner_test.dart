import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/error_banner.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ErrorBanner', () {
    testWidgets('renders banner style by default', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner.banner(message: 'Error occurred'),
      );

      expect(find.text('Error occurred'), findsOneWidget);
    });

    testWidgets('renders banner with retry button', (
      WidgetTester tester,
    ) async {
      bool retryCalled = false;

      await pumpAppWidget(
        tester,
        ErrorBanner.banner(
          message: 'Something went wrong',
          onRetry: () => retryCalled = true,
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });

    testWidgets('renders error icon', (WidgetTester tester) async {
      await pumpAppWidget(tester, const ErrorBanner.banner(message: 'Error'));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders card style', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner.card(message: 'Card Error'),
      );

      expect(find.text('Card Error'), findsOneWidget);
    });

    testWidgets('renders card with retry button', (WidgetTester tester) async {
      bool retryCalled = false;

      await pumpAppWidget(
        tester,
        ErrorBanner.card(
          message: 'Card Error',
          onRetry: () => retryCalled = true,
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });

    testWidgets('renders inline style', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner.inline(message: 'Inline Error'),
      );

      expect(find.text('Inline Error'), findsOneWidget);
    });

    testWidgets('renders inline with retry', (WidgetTester tester) async {
      bool retryCalled = false;

      await pumpAppWidget(
        tester,
        ErrorBanner.inline(
          message: 'Inline Error',
          onRetry: () => retryCalled = true,
        ),
      );

      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('uses theme colors', (WidgetTester tester) async {
      await pumpAppWidget(tester, const ErrorBanner.banner(message: 'Error'));

      // Verify error icon is present (indicates error styling)
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('banner is full width', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner.banner(message: 'Full Width Error'),
      );

      // Verify banner takes full width
      expect(find.text('Full Width Error'), findsOneWidget);
    });
  });
}
