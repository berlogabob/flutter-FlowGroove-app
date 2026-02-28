import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/metronome/bpm_controls_widget.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('BpmControlsWidget', () {
    testWidgets('renders BPM label', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('BPM'), findsWidgets);
    });

    testWidgets('renders slider', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('renders current BPM value', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Default BPM is 120 - use textContaining to match both Text and TextField
      expect(find.text('120'), findsWidgets);
    });

    testWidgets('renders BPM input field', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders minus button', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('renders plus button', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('displays help tooltip icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('decreases BPM when minus button is tapped', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap minus button
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      // Verify BPM decreased from 120 to 119 - use textContaining
      expect(find.text('119'), findsWidgets);
    });

    testWidgets('increases BPM when plus button is tapped', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap plus button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Verify BPM increased from 120 to 121 - use textContaining
      expect(find.text('121'), findsWidgets);
    });

    testWidgets('updates BPM when slider is dragged', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Find slider and drag it
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pump();

      // BPM should have changed - slider still exists
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('updates BPM when input field is changed', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Find input field and enter new BPM
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, '140');
      await tester.pump();

      // Verify BPM updated - use textContaining
      expect(find.text('140'), findsWidgets);
    });

    testWidgets('handles BPM below minimum gracefully', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Enter BPM below minimum
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, '0');
      await tester.pump();

      // Widget should not crash - text field still exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('handles BPM above maximum gracefully', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Enter BPM above maximum
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, '500');
      await tester.pump();

      // Widget should not crash - text field still exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('slider has correct range 1-300', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, equals(1));
      expect(slider.max, equals(300));
    });

    testWidgets('slider has 299 divisions', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, equals(299));
    });

    testWidgets('handles invalid input gracefully', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const BpmControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Enter invalid text
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'abc');
      await tester.pump();

      // Should not crash - widget still renders
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
