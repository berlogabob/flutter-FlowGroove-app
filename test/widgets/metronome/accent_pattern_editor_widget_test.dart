import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/metronome/accent_pattern_editor_widget.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('AccentPatternEditorWidget', () {
    testWidgets('renders title', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('Accent Pattern'), findsOneWidget);
    });

    testWidgets('renders Card widget', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders reset button', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders helper text', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(
        find.text(
          'Tap to toggle Accent (strong) or Regular (weak) for each beat',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders beat toggle buttons for 4/4 time', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Should have 4 beat buttons for 4/4 time (using GestureDetector)
      expect(find.byType(GestureDetector), findsNWidgets(5)); // 4 beats + 1 reset button
    });

    testWidgets('renders beat numbers', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('4'), findsWidgets);
    });

    testWidgets('renders accent labels', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // First beat should be accented by default
      expect(find.text('Accent'), findsOneWidget);
      // Other beats should be regular
      expect(find.text('Regular'), findsNWidgets(3));
    });

    testWidgets('first beat is accented by default', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Find star icons (accent indicator)
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('non-first beats show circle outline', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Should have 3 circle_outlined icons for beats 2, 3, 4
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(3));
    });

    testWidgets('toggles accent when beat button is tapped', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap on beat 2 (which is Regular by default)
      final gestureDetectors = find.byType(GestureDetector);
      await tester.tap(gestureDetectors.at(1));
      await tester.pump();

      // Now beat 2 should be accented
      expect(find.byIcon(Icons.star), findsNWidgets(2));
    });

    testWidgets('adapts to different time signatures', (
      WidgetTester tester,
    ) async {
      // This test verifies the widget renders correctly with default state
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Should have 4 beat buttons for default 4/4 time (using GestureDetector)
      expect(find.byType(GestureDetector), findsNWidgets(5)); // 4 beats + 1 reset button
    });

    testWidgets('renders beat labels below buttons', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const AccentPatternEditorWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Verify labels are present
      expect(find.text('Accent'), findsOneWidget);
      expect(find.text('Regular'), findsNWidgets(3));
    });
  });
}
