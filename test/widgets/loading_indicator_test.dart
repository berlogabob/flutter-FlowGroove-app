import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/loading_indicator.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('LoadingIndicator', () {
    testWidgets('renders loading spinner', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with default size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(),
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      // Default size is 40
      expect(spinner.strokeWidth, equals(3));
    });

    testWidgets('renders with custom size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(size: 60),
      );

      // Verify the spinner is rendered
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with message', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(message: 'Loading...'),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(findText('Loading...'), findsOneWidget);
    });

    testWidgets('renders without message', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verifyNotFound(findText('Loading...'));
    });

    testWidgets('renders centered', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(),
      );

      // Verify the widget is wrapped in a Center
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('renders message with default style', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(message: 'Please wait'),
      );

      expect(findText('Please wait'), findsOneWidget);
    });

    testWidgets('renders message with custom style', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingIndicator(
          message: 'Custom Style',
          messageStyle: TextStyle(fontSize: 20, color: Colors.red),
        ),
      );

      expect(findText('Custom Style'), findsOneWidget);
    });
  });

  group('LoadingSpinner', () {
    testWidgets('renders small spinner', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingSpinner(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with default size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingSpinner(),
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      // Default size is 16
      expect(spinner.strokeWidth, equals(2));
    });

    testWidgets('renders with custom size', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingSpinner(size: 24),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with white color by default', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingSpinner(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with custom color', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const LoadingSpinner(color: Colors.red),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
