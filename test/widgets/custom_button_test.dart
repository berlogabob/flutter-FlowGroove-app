import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('CustomButton', () {
    testWidgets('renders primary button with label', (
      tester,
    ) async {
      await pumpAppWidget(tester, const CustomButton(label: 'Click Me'));

      expect(findText('Click Me'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders secondary button', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(
          label: 'Secondary',
          variant: ButtonVariant.secondary,
        ),
      );

      expect(findText('Secondary'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders outline button', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Outline', variant: ButtonVariant.outline),
      );

      expect(findText('Outline'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('renders text button', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Text', variant: ButtonVariant.text),
      );

      expect(findText('Text'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('renders button with icon', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'With Icon', icon: Icons.add),
      );

      expect(findText('With Icon'), findsOneWidget);
      expect(findIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders loading state', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Loading', isLoading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(findText('Loading'), findsOneWidget);
    });

    testWidgets('renders loading state without label', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: '', isLoading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool wasPressed = false;

      await pumpAppWidget(
        tester,
        CustomButton(label: 'Press Me', onPressed: () => wasPressed = true),
      );

      await tester.tap(findText('Press Me'));
      await tester.pump();

      expect(wasPressed, isTrue);
    });

    testWidgets('does not call onPressed when disabled', (
      tester,
    ) async {
      const bool wasPressed = false;

      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Disabled'),
      );

      await tester.tap(findText('Disabled'));
      await tester.pump();

      expect(wasPressed, isFalse);
    });

    testWidgets('does not call onPressed when loading', (
      tester,
    ) async {
      bool wasPressed = false;

      await pumpAppWidget(
        tester,
        CustomButton(
          label: 'Loading',
          isLoading: true,
          onPressed: () => wasPressed = false,
        ),
      );

      await tester.tap(findText('Loading'));
      await tester.pump();

      expect(wasPressed, isFalse);
    });

    testWidgets('renders full width button', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Full Width', fullWidth: true),
      );

      final buttonFinder = find.byType(ElevatedButton);
      final buttonSize = tester.getSize(buttonFinder);
      final screenSize = tester.getSize(find.byType(MaterialApp));

      expect(buttonSize.width, equals(screenSize.width));
    });

    testWidgets('renders small button', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Small', size: ButtonSize.small),
      );

      expect(findText('Small'), findsOneWidget);
    });

    testWidgets('renders medium button', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Medium'),
      );

      expect(findText('Medium'), findsOneWidget);
    });

    testWidgets('renders large button', (tester) async {
      await pumpAppWidget(
        tester,
        const CustomButton(label: 'Large', size: ButtonSize.large),
      );

      expect(findText('Large'), findsOneWidget);
    });

    testWidgets('renders button without icon when icon is null', (
      tester,
    ) async {
      await pumpAppWidget(tester, const CustomButton(label: 'No Icon'));

      expect(findText('No Icon'), findsOneWidget);
    });
  });
}
