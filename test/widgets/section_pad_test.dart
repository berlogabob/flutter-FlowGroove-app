import 'package:flowgroove/utils/pad_state.dart';
import 'package:flowgroove/widgets/practice/section_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    PadState state = PadState.idle,
    VoidCallback? onTap,
    double width = 320,
    double textScaleFactor = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScaleFactor),
            ),
            child: SizedBox(
              width: width,
              child: SectionPad(
                name: 'Chorus',
                bars: 4,
                color: Colors.blue,
                state: state,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('SectionPad', () {
    testWidgets('queued pad names the quantize it waits for', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionPad(
              name: 'Chorus',
              bars: 4,
              color: Colors.blue,
              state: PadState.queued,
              queuedLabel: 'Next block',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Next block'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Chorus, Starts next block'),
        findsOneWidget,
      );
    });

    testWidgets('fills the width it is given regardless of label', (
      tester,
    ) async {
      await pump(tester, width: 180);
      expect(tester.getSize(find.byType(SectionPad)).width, 180);
    });

    testWidgets('idle shows name and bar count', (tester) async {
      await pump(tester);

      expect(find.text('Chorus'), findsOneWidget);
      expect(find.text('4 bars'), findsOneWidget);
    });

    testWidgets('queued shows Next bar', (tester) async {
      await pump(tester, state: PadState.queued);

      expect(find.text('Next bar'), findsOneWidget);
    });

    testWidgets('playing shows play icon', (tester) async {
      await pump(tester, state: PadState.playing);

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('tap calls onTap', (tester) async {
      var taps = 0;
      await pump(tester, onTap: () => taps++);

      await tester.tap(find.text('Chorus'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('queued semantics includes name and state', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, state: PadState.queued);

      expect(
        find.bySemanticsLabel(RegExp('Chorus, Starts next bar')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final state in PadState.values) {
      testWidgets('${state.name} fits narrow width with large text', (
        tester,
      ) async {
        await pump(tester, state: state, width: 160, textScaleFactor: 2);

        expect(tester.takeException(), isNull);
      });
    }
  });
}
