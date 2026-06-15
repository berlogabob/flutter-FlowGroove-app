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

    testWidgets('main beat row scrolls above 6 dots', (tester) async {
      await pumpBlock(tester, width: 320);
      await tapNTimes(tester, const Key('main-beats-increment'), 3);

      expectMainDots(7);
      expect(find.byKey(const Key('main-beat-strip-scroll')), findsOneWidget);
    });

    testWidgets('subdivision row fits 6 dots before scrolling', (tester) async {
      await pumpBlock(tester, width: 320);
      await tapNTimes(tester, const Key('subdivisions-increment'), 5);

      expectSubdivisionDots(6);
      expect(find.byKey(const Key('subdivision_dot_6')), findsNothing);
      expect(find.byKey(const Key('subdivision-strip-scroll')), findsNothing);
    });

    testWidgets('subdivision row scrolls above 6 dots', (tester) async {
      await pumpBlock(tester, width: 320);
      await tapNTimes(tester, const Key('subdivisions-increment'), 6);

      expectSubdivisionDots(7);
      expect(find.byKey(const Key('subdivision-strip-scroll')), findsOneWidget);
    });
  });
}
