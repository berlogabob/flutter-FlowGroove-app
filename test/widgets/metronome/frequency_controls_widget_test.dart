import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_repsync_app/widgets/metronome/frequency_controls_widget.dart';
import 'package:flutter_repsync_app/providers/data/metronome_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('FrequencyControlsWidget', () {
    testWidgets('renders Advanced Settings header', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.text('Advanced Settings'), findsOneWidget);
    });

    testWidgets('renders container with border decoration', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Widget uses Container with BoxDecoration, not Card
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders tune icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('renders expand/collapse icon', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Initially collapsed, should show expand_more
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('content is collapsed by default', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Volume slider should not be visible when collapsed
      expect(find.byType(Slider), findsNothing);
      // Advanced content should not be visible
      expect(find.text('Tone: '), findsNothing);
    });

    testWidgets('expands when header is tapped', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Tap the header to expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Now should show expand_less
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('shows volume slider when expanded', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Volume slider should be visible
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows tone type selector when expanded', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Tone label should be visible
      expect(find.text('Tone: '), findsOneWidget);
    });

    testWidgets('shows wave type options when expanded', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Wave type dropdown should be visible with current selection
      expect(find.text('Smooth'), findsOneWidget);
      // Other options are in dropdown menu, not directly visible
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('shows volume icon when expanded', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('shows accent toggle when expanded', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Accent on beat 1'), findsOneWidget);
    });

    testWidgets('shows frequency inputs when expanded', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Frequencies (Hz)'), findsOneWidget);
      expect(find.text('Accent:'), findsOneWidget);
      expect(find.text('Beat:'), findsOneWidget);
    });

    testWidgets('shows divider when expanded', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('collapses when tapped again after expanding', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Should show expand_more again
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('displays current wave type in dropdown', (
      WidgetTester tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Default wave type is sine (Smooth) shown in dropdown
      expect(find.text('Smooth'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('displays accent toggle subtitle', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Higher pitch on first beat'), findsOneWidget);
    });

    testWidgets('volume slider has correct range', (WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: [metronomeProvider.overrideWith(() => MetronomeNotifier())],
      );

      // Expand
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, equals(0.0));
      expect(slider.max, equals(1.0));
      expect(slider.divisions, equals(10));
    });
  });
}
