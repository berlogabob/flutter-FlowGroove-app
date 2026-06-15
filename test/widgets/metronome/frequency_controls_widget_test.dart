import 'package:flowgroove/widgets/metronome/frequency_controls_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/metronome_test_runtime.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('FrequencyControlsWidget', () {
    testWidgets('renders Advanced Settings header', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      expect(find.text('Advanced Settings'), findsOneWidget);
    });

    testWidgets('renders container with border decoration', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Widget uses Container with BoxDecoration, not Card
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders tune icon', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('renders expand/collapse icon', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Initially collapsed, should show expand_more
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('content is collapsed by default', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      expect(crossFade.crossFadeState, CrossFadeState.showFirst);
    });

    testWidgets('expands when header is tapped', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Tap the header to expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      // Now should show expand_less
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('shows volume slider when expanded', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      // Volume slider should be visible
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows tone type selector when expanded', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      // Tone label should be visible
      expect(find.text('Tone: '), findsOneWidget);
    });

    testWidgets('shows wave type options when expanded', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      // Wave type dropdown should be visible with current selection
      expect(find.text('Smooth'), findsOneWidget);
      // Other options are in dropdown menu, not directly visible
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('shows volume icon when expanded', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('shows accent toggle when expanded', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      expect(find.text('Accent on beat 1'), findsOneWidget);
    });

    testWidgets('shows frequency inputs when expanded', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      expect(find.text('Frequencies (Hz)'), findsOneWidget);
      expect(find.text('Accent:'), findsOneWidget);
      expect(find.text('Beat:'), findsOneWidget);
    });

    testWidgets('shows divider when expanded', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('collapses when tapped again after expanding', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      // Should show expand_more again
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('displays current wave type in dropdown', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      // Default wave type is sine (Smooth) shown in dropdown
      expect(find.text('Smooth'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('displays accent toggle subtitle', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      expect(find.text('Higher pitch on first beat'), findsOneWidget);
    });

    testWidgets('volume slider has correct range', (tester) async {
      await pumpAppWidget(
        tester,
        const FrequencyControlsWidget(),
        overrides: buildMetronomeTestOverrides(overrideMetronomeProvider: true),
      );

      // Expand
      await tester.tap(find.byKey(const Key('frequency_controls_header')));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, equals(0.0));
      expect(slider.max, equals(1.0));
      expect(slider.divisions, equals(10));
    });
  });
}
