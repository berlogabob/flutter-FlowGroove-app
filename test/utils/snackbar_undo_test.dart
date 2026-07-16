import 'package:flowgroove/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('showAppSnackBar - Action Rendering', () {
    testWidgets('renders snackbar with action when both actionLabel and onAction provided',
        (WidgetTester tester) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAppSnackBar(
                    context,
                    'Test message',
                    actionLabel: 'Undo',
                    onAction: () {
                      actionCalled = true;
                    },
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      // Trigger the snackbar
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify message is displayed
      expect(find.text('Test message'), findsOneWidget);

      // Verify action button is displayed
      expect(find.text('Undo'), findsOneWidget);

      // Tap the action button
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(actionCalled, true);
    });

    testWidgets('renders snackbar without action when only message provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAppSnackBar(context, 'Test message');
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      // Trigger the snackbar
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify message is displayed
      expect(find.text('Test message'), findsOneWidget);

      // Verify no action button is present
      expect(find.byType(SnackBarAction), findsNothing);
    });

    testWidgets('uses longer duration when action is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAppSnackBar(
                    context,
                    'Test message',
                    actionLabel: 'Undo',
                    onAction: () {},
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      // Trigger the snackbar
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Find the SnackBar and verify duration
      final SnackBar snackBar = find
          .byType(SnackBar)
          .evaluate()
          .single
          .widget as SnackBar;

      expect(snackBar.duration, const Duration(seconds: 5));
    });

    testWidgets('ignores onAction if actionLabel is null',
        (WidgetTester tester) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAppSnackBar(
                    context,
                    'Test message',
                    onAction: () {
                      actionCalled = true;
                    },
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      // Trigger the snackbar
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify message is displayed
      expect(find.text('Test message'), findsOneWidget);

      // Verify no action button is present (actionLabel was null)
      expect(find.byType(SnackBarAction), findsNothing);

      // Wait for snackbar to disappear
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify callback was NOT called
      expect(actionCalled, false);
    });
  });
}
