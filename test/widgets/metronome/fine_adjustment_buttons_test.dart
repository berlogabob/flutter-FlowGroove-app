import 'package:flowgroove/widgets/metronome/fine_adjustment_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/metronome_test_runtime.dart';

void main() {
  group('FineAdjustmentButtons', () {
    testWidgets('adjusts BPM without showing a snackbar', (
      tester,
    ) async {
      final runtime = MetronomeTestRuntime();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildMetronomeTestOverrides(
            runtime: runtime,
            overrideMetronomeProvider: true,
          ),
          child: const MaterialApp(
            home: Scaffold(body: FineAdjustmentButtons()),
          ),
        ),
      );

      await tester.tap(find.byTooltip('-1 BPM'));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
