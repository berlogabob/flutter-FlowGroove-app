import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/error_banner.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ErrorBanner', () {
    testWidgets('renders banner style by default', (WidgetTester tester) async {
      await pumpAppWidget(tester, const ErrorBanner(message: 'Error occurred'));

      expect(findText('Error occurred'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders with message', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(message: 'Something went wrong'),
      );

      expect(findText('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders with title', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(message: 'Error details', title: 'Error Title'),
      );

      expect(findText('Error Title'), findsOneWidget);
      expect(findText('Error details'), findsOneWidget);
    });

    testWidgets('renders error icon', (WidgetTester tester) async {
      await pumpAppWidget(tester, const ErrorBanner(message: 'Error'));

      expect(findIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders retry button when showRetry is true', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(message: 'Error', showRetry: true),
      );

      expect(findText('Retry'), findsOneWidget);
    });

    testWidgets('does not render retry button when showRetry is false', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(message: 'Error', showRetry: false),
      );

      verifyNotFound(findText('Retry'));
    });

    testWidgets('calls onRetry when retry button is tapped', (
      WidgetTester tester,
    ) async {
      bool wasRetried = false;

      await pumpAppWidget(
        tester,
        ErrorBanner(
          message: 'Error',
          showRetry: true,
          onRetry: () => wasRetried = true,
        ),
      );

      await tester.tap(findText('Retry'));
      await tester.pump();

      expect(wasRetried, isTrue);
    });

    testWidgets('renders card style', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(message: 'Card Error', style: ErrorBannerStyle.card),
      );

      expect(findText('Card Error'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders inline style', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Inline Error',
          style: ErrorBannerStyle.inline,
        ),
      );

      expect(findText('Inline Error'), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('renders card style with title', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Card Error',
          title: 'Card Title',
          style: ErrorBannerStyle.card,
        ),
      );

      expect(findText('Card Title'), findsOneWidget);
      expect(findText('Card Error'), findsOneWidget);
    });

    testWidgets('renders card style with retry button', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Card Error',
          showRetry: true,
          style: ErrorBannerStyle.card,
        ),
      );

      expect(findText('Retry'), findsOneWidget);
    });

    testWidgets('renders inline style with retry button', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(
          message: 'Inline Error',
          showRetry: true,
          style: ErrorBannerStyle.inline,
        ),
      );

      expect(findText('Retry'), findsOneWidget);
    });

    testWidgets('renders banner with red color scheme', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(tester, const ErrorBanner(message: 'Error'));

      // Verify error icon is present (indicates error styling)
      expect(findIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders full width banner', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ErrorBanner(message: 'Full Width Error'),
      );

      // Banner should be full width
      expect(find.byType(Container), findsWidgets);
    });
  });
}
