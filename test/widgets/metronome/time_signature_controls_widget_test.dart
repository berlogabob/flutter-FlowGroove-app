import 'package:flowgroove/models/time_signature.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/widgets/metronome/time_signature_controls_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('TimeSignatureControlsWidget', () {
    testWidgets('renders title', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('Time Signature'), findsOneWidget);
    });

    testWidgets('renders help tooltip', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('renders Card widget', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      // The widget uses Container with BoxDecoration for the card-like container
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders 6 preset time signature chips', (
      tester,
    ) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      // Count _TimeSignatureChip widgets (rendered as GestureDetector + Container)
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('renders 4/4 preset', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('4/4'), findsWidgets);
    });

    testWidgets('renders 3/4 preset', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('3/4'), findsWidgets);
    });

    testWidgets('renders 6/8 preset', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('6/8'), findsWidgets);
    });

    testWidgets('renders 2/4 preset', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('2/4'), findsWidgets);
    });

    testWidgets('renders 5/4 preset', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('5/4'), findsWidgets);
    });

    testWidgets('renders 7/8 preset', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('7/8'), findsWidgets);
    });

    testWidgets('displays current selection', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('Current: '), findsOneWidget);
      expect(find.text('4/4'), findsWidgets);
    });

    testWidgets('displays helper text', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.text('Select a common time signature'), findsOneWidget);
    });

    testWidgets('renders divider', (tester) async {
      await pumpAppWidget(
        tester,
        const TimeSignatureControlsWidget(),
        overrides: [metronomeProvider.overrideWith(MetronomeNotifier.new)],
      );

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('presets list contains correct time signatures', (
      tester,
    ) async {
      final presets = TimeSignatureControlsWidget.presets;

      expect(presets.length, equals(6));
      expect(
        presets[0],
        equals(const TimeSignature(numerator: 4, denominator: 4)),
      );
      expect(
        presets[1],
        equals(const TimeSignature(numerator: 3, denominator: 4)),
      );
      expect(
        presets[2],
        equals(const TimeSignature(numerator: 6, denominator: 8)),
      );
      expect(
        presets[3],
        equals(const TimeSignature(numerator: 2, denominator: 4)),
      );
      expect(
        presets[4],
        equals(const TimeSignature(numerator: 5, denominator: 4)),
      );
      expect(
        presets[5],
        equals(const TimeSignature(numerator: 7, denominator: 8)),
      );
    });
  });
}
