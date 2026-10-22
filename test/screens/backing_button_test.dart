import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/widgets/bottom_nav_or_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/metronome_test_runtime.dart';

void main() {
  testWidgets(
    'backing button stays above bottom inset and explains missing song',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 80);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      final runtime = MetronomeTestRuntime();
      final container = ProviderContainer(overrides: runtime.overrides);
      addTearDown(() async {
        container.dispose();
        await runtime.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MetronomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithText(OutlinedButton, 'Backing tracks');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      expect(tester.getRect(button).bottom, lessThanOrEqualTo(640 - 80));
      expect(
        tester.getRect(button).bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBottomBar)).dy),
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text(
          'Pick a song first, then add a MIDI file or drum pattern to it',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
