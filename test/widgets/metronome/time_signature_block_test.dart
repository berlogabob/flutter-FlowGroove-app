import 'package:flowgroove/widgets/metronome/time_signature_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/metronome_test_runtime.dart';

void main() {
  Future<void> pumpBlock(WidgetTester tester, {required double width}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: ProviderScope(
            overrides: buildMetronomeTestOverrides(
              overrideMetronomeProvider: true,
            ),
            child: const Scaffold(body: Center(child: TimeSignatureBlock())),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapNTimes(WidgetTester tester, Key key, int count) async {
    for (var index = 0; index < count; index += 1) {
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
  }

  void expectMainDots(int count) {
    for (var index = 0; index < count; index += 1) {
      expect(find.byKey(Key('main_beat_dot_$index')), findsOneWidget);
      expect(find.bySemanticsLabel('Main beat ${index + 1}'), findsOneWidget);
    }
  }

  void expectSubdivisionDots(int count) {
    for (var index = 0; index < count; index += 1) {
      expect(find.byKey(Key('subdivision_dot_$index')), findsOneWidget);
      expect(find.bySemanticsLabel('Subdivision ${index + 1}'), findsOneWidget);
    }
  }

  group('TimeSignatureBlock dot rows', () {
    for (final width in <double>[320, 375, 400]) {
      testWidgets('default 4/4 shows 4 main dots at ${width.toInt()} px', (
        tester,
      ) async {
        await pumpBlock(tester, width: width);

        expect(find.text('Beats'), findsOneWidget);
        expect(find.text('Subdivision'), findsOneWidget);
        expectMainDots(4);
        expect(find.byKey(const Key('main_beat_dot_4')), findsNothing);
        expect(find.byKey(const Key('main-beat-strip-scroll')), findsNothing);
      });

      testWidgets('6 beats fit before scrolling at ${width.toInt()} px', (
        tester,
      ) async {
        await pumpBlock(tester, width: width);
        await tapNTimes(tester, const Key('main-beats-increment'), 2);

        expectMainDots(6);
        expect(find.byKey(const Key('main_beat_dot_6')), findsNothing);
        expect(find.byKey(const Key('main-beat-strip-scroll')), findsNothing);
      });
    }

    testWidgets('main beat row keeps all 12 dots visible at 400 px', (
      tester,
    ) async {
      await pumpBlock(tester, width: 400);
      await tapNTimes(tester, const Key('main-beats-increment'), 8); // 4 -> 12

      expectMainDots(12);
      expect(find.byKey(const Key('main-beat-strip-scroll')), findsNothing);
    });

    testWidgets('no main dot is ever dropped, even at 320 px', (tester) async {
      await pumpBlock(tester, width: 320);
      await tapNTimes(tester, const Key('main-beats-increment'), 8); // 4 -> 12

      // The design never hides a beat: all 12 stay in the tree (fitting, or
      // scrollable as the narrow-screen safety net).
      expectMainDots(12);
    });

    testWidgets('subdivision row fits 6 dots without scrolling', (
      tester,
    ) async {
      await pumpBlock(tester, width: 320);
      await tapNTimes(tester, const Key('subdivisions-increment'), 5); // 1 -> 6

      expectSubdivisionDots(6);
      expect(find.byKey(const Key('subdivision_dot_6')), findsNothing);
      expect(find.byKey(const Key('subdivision-strip-scroll')), findsNothing);
    });

    testWidgets('subdivision row keeps all 12 dots visible at 400 px', (
      tester,
    ) async {
      await pumpBlock(tester, width: 400);
      await tapNTimes(tester, const Key('subdivisions-increment'), 11); // 1->12

      expectSubdivisionDots(12);
      expect(find.byKey(const Key('subdivision-strip-scroll')), findsNothing);
    });
  });
}
