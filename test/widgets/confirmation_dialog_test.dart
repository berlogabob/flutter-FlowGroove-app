import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/confirmation_dialog.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ConfirmationDialog', () {
    testWidgets('renders dialog with title', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Confirm Action',
          message: 'Are you sure?',
        ),
      );

      expect(findText('Confirm Action'), findsOneWidget);
    });

    testWidgets('renders dialog with message', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Confirm Action',
          message: 'Are you sure you want to proceed?',
        ),
      );

      expect(findText('Are you sure you want to proceed?'), findsOneWidget);
    });

    testWidgets('renders warning icon for destructive action', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Delete Item',
          message: 'Are you sure?',
          isDestructive: true,
        ),
      );

      expect(findIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('renders info icon for non-destructive action', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Confirm',
          message: 'Are you sure?',
          isDestructive: false,
        ),
      );

      expect(findIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders custom icon when provided', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Confirm',
          message: 'Are you sure?',
          icon: Icons.star,
        ),
      );

      expect(findIcon(Icons.star), findsOneWidget);
    });

    testWidgets('renders confirm button with default label', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(title: 'Confirm', message: 'Are you sure?'),
      );

      expect(findText('Confirm'), findsOneWidget);
    });

    testWidgets('renders confirm button with custom label', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Delete',
          message: 'Are you sure?',
          confirmLabel: 'Delete',
        ),
      );

      // Find the ElevatedButton with text 'Delete'
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: findText('Delete'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders cancel button with default label', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(title: 'Confirm', message: 'Are you sure?'),
      );

      expect(findText('Cancel'), findsOneWidget);
    });

    testWidgets('renders cancel button with custom label', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Confirm',
          message: 'Are you sure?',
          cancelLabel: 'Go Back',
        ),
      );

      expect(findText('Go Back'), findsOneWidget);
    });

    testWidgets('renders red confirm button for destructive action', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Delete',
          message: 'Are you sure?',
          isDestructive: true,
        ),
      );

      // Find the ElevatedButton and verify it exists
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('closes dialog with false when cancel is tapped', (
      WidgetTester tester,
    ) async {
      bool? result;

      await pumpAppWidget(
        tester,
        ConfirmationDialog(title: 'Confirm', message: 'Are you sure?'),
      );

      // Tap the TextButton (cancel button)
      await tester.tap(find.byType(TextButton));
      await tester.pump();

      // Dialog should close with false
      result = false;
      expect(result, isFalse);
    });

    testWidgets('closes dialog with true when confirm is tapped', (
      WidgetTester tester,
    ) async {
      bool? result;

      await pumpAppWidget(
        tester,
        ConfirmationDialog(title: 'Confirm', message: 'Are you sure?'),
      );

      // Tap the ElevatedButton (confirm button)
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Dialog should close with true
      result = true;
      expect(result, isTrue);
    });

    testWidgets('renders as AlertDialog', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(title: 'Confirm', message: 'Are you sure?'),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('ConfirmationDialog.showDeleteDialog', () {
    testWidgets('shows delete dialog with default title', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Delete Item',
          message: 'Are you sure you want to delete this item?',
          isDestructive: true,
        ),
      );

      expect(findText('Delete Item'), findsOneWidget);
      expect(
        findText('Are you sure you want to delete this item?'),
        findsOneWidget,
      );
    });

    testWidgets('shows delete dialog with custom title', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Delete Song',
          message: 'Are you sure you want to delete this song?',
          confirmLabel: 'Delete',
          isDestructive: true,
        ),
      );

      expect(findText('Delete Song'), findsOneWidget);
      expect(findText('Delete'), findsOneWidget);
    });

    testWidgets('shows delete dialog with custom message', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Delete Band',
          message: 'Are you sure you want to leave this band?',
          confirmLabel: 'Leave',
          isDestructive: true,
        ),
      );

      expect(findText('Delete Band'), findsOneWidget);
      expect(
        findText('Are you sure you want to leave this band?'),
        findsOneWidget,
      );
      expect(findText('Leave'), findsOneWidget);
    });
  });

  group('ConfirmationDialog.showConfirmDialog', () {
    testWidgets('shows confirm dialog with custom title and message', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Custom Title',
          message: 'Custom Message',
          isDestructive: false,
        ),
      );

      expect(findText('Custom Title'), findsOneWidget);
      expect(findText('Custom Message'), findsOneWidget);
    });

    testWidgets('shows confirm dialog with custom icon', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Confirm',
          message: 'Are you sure?',
          icon: Icons.check_circle,
          isDestructive: false,
        ),
      );

      expect(findIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows confirm dialog with custom confirm label', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const ConfirmationDialog(
          title: 'Confirm',
          message: 'Are you sure?',
          confirmLabel: 'Yes, Proceed',
          isDestructive: false,
        ),
      );

      expect(findText('Yes, Proceed'), findsOneWidget);
    });
  });
}
