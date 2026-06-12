import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/widgets/metronome/central_tempo_circle.dart';
import 'package:flowgroove/widgets/metronome/tempo_dial_scale.dart';

import '../../helpers/metronome_test_runtime.dart';

void main() {
  late ProviderContainer container;
  late MetronomeTestRuntime runtime;

  setUp(() {
    runtime = MetronomeTestRuntime();
    container = ProviderContainer(overrides: runtime.overrides);
  });

  tearDown(() async {
    container.dispose();
    await runtime.dispose();
  });

  Future<void> pumpDial(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 300,
                child: CentralTempoCircle(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Offset globalPointFor(WidgetTester tester, int bpm) {
    final rect = tester.getRect(find.byKey(const Key('tempo-dial')));
    final angle = TempoDialScale.bpmToAngle(bpm);
    return rect.center +
        Offset(math.cos(angle), math.sin(angle)) * (rect.width / 2 - 20);
  }

  testWidgets('ring tap maps directly to BPM', (tester) async {
    await pumpDial(tester);

    await tester.tapAt(globalPointFor(tester, 320));
    await tester.pump();

    expect(container.read(metronomeProvider).bpm, closeTo(320, 1));
  });

  testWidgets(
    'clockwise drag increases and counterclockwise drag decreases BPM',
    (tester) async {
      await pumpDial(tester);

      final gesture = await tester.startGesture(globalPointFor(tester, 80));
      await gesture.moveTo(globalPointFor(tester, 320));
      await gesture.up();
      await tester.pump();
      expect(container.read(metronomeProvider).bpm, closeTo(320, 1));

      final reverseGesture = await tester.startGesture(
        globalPointFor(tester, 320),
      );
      await reverseGesture.moveTo(globalPointFor(tester, 80));
      await reverseGesture.up();
      await tester.pump();
      expect(container.read(metronomeProvider).bpm, closeTo(80, 1));
    },
  );

  testWidgets('center and bottom gap do not update BPM', (tester) async {
    await pumpDial(tester);
    container.read(metronomeProvider.notifier).setBpm(222);
    await tester.pump();
    final rect = tester.getRect(find.byKey(const Key('tempo-dial')));

    final centerDrag = await tester.startGesture(rect.center);
    await centerDrag.moveBy(const Offset(5, 5));
    await centerDrag.up();
    final gapDrag = await tester.startGesture(
      Offset(rect.center.dx, rect.bottom - 10),
    );
    await gapDrag.moveBy(const Offset(5, 0));
    await gapDrag.up();
    await tester.pump();

    expect(container.read(metronomeProvider).bpm, 222);
  });

  testWidgets('center tap opens numeric input', (tester) async {
    await pumpDial(tester);
    final rect = tester.getRect(find.byKey(const Key('tempo-dial')));

    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();

    expect(find.text('Set BPM'), findsOneWidget);
    expect(find.text('1-400 BPM'), findsOneWidget);
  });

  testWidgets('external BPM changes reposition the indicator immediately', (
    tester,
  ) async {
    await pumpDial(tester);

    container.read(metronomeProvider.notifier).setBpm(320);
    await tester.pump();

    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    final painter = paints
        .map((paint) => paint.painter)
        .whereType<TempoDialPainter>()
        .single;
    expect(painter.bpm, 320);
    expect(find.text('320'), findsOneWidget);
  });

  testWidgets('does not scale or pop the dial while playing', (tester) async {
    await pumpDial(tester);

    container.read(metronomeProvider.notifier).start();
    runtime.playback.emitTick(0);
    await tester.pump();

    final dial = find.byKey(const Key('tempo-dial'));
    expect(
      find.descendant(of: dial, matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
    expect(
      find.descendant(of: dial, matching: find.byType(Transform)),
      findsNothing,
    );
  });
}
