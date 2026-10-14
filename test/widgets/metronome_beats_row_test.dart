import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/widgets/metronome/time_signature_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestMetronomeNotifier extends MetronomeNotifier {
  _TestMetronomeNotifier(this.beats);

  final int beats;

  @override
  MetronomeState build() =>
      MetronomeState.initial().copyWith(accentBeats: beats);
}

void main() {
  for (var beats = 1; beats <= 12; beats++) {
    testWidgets('$beats beats have visible 44dp targets at 360dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            metronomeProvider.overrideWith(() => _TestMetronomeNotifier(beats)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                // Match the Metronome screen's horizontal padding.
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TimeSignatureBlock(),
              ),
            ),
          ),
        ),
      );

      final dots = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'main_beat_dot_',
            ),
      );
      expect(dots, findsNWidgets(beats));
      for (var index = 0; index < beats; index++) {
        final dot = find.byKey(Key('main_beat_dot_$index'));
        expect(tester.getSize(dot).width, greaterThanOrEqualTo(44));
        expect(dot.hitTestable(), findsOneWidget);
        final rect = tester.getRect(dot);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
