import 'package:flowgroove/widgets/error_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('ErrorBanner', () {
    testWidgets('renders banner style by default', (tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Error occurred',
        ),
      );

      expect(find.text('Error occurred'), findsOneWidget);
    });

    testWidgets('renders banner with retry button', (
      tester,
    ) async {
      bool retryCalled = false;

      await pumpAppWidget(
        tester,
        ErrorBanner(
          message: 'Something went wrong',
          onRetry: () => retryCalled = true,
          showRetry: true,
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });

    testWidgets('renders error icon', (tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Error',
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders card style', (tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Card Error',
          style: ErrorBannerStyle.card,
        ),
      );

      expect(find.text('Card Error'), findsOneWidget);
    });

    testWidgets('renders card with retry button', (tester) async {
      bool retryCalled = false;

      await pumpAppWidget(
        tester,
        ErrorBanner(
          message: 'Card Error',
          onRetry: () => retryCalled = true,
          showRetry: true,
          style: ErrorBannerStyle.card,
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });

    testWidgets('renders inline style', (tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Inline Error',
          style: ErrorBannerStyle.inline,
        ),
      );

      expect(find.text('Inline Error'), findsOneWidget);
    });

    testWidgets('renders inline with retry', (tester) async {
      await pumpAppWidget(
        tester,
        ErrorBanner(
          message: 'Inline Error',
          onRetry: () {},
          showRetry: true,
          style: ErrorBannerStyle.inline,
        ),
      );

      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('uses theme colors', (tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Error',
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('banner is full width', (tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Full Width Error',
        ),
      );

      expect(find.text('Full Width Error'), findsOneWidget);
    });
  });
}
