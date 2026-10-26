import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/tuner/transport_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tuner extends TunerNotifier {
  @override
  TunerState build() => const TunerState();
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('calibration label fits at width 320 and text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tunerProvider.overrideWith(_Tuner.new)],
          child: MaterialApp(
            theme: MonoPulseTheme.theme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(body: TransportBar()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text('A4 440');
      expect(label, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.text.style!.fontSize, greaterThanOrEqualTo(11));
      expect(paragraph.size.width, greaterThan(0));
      expect(paragraph.size.height, greaterThan(0));
      final cell = find
          .ancestor(of: label, matching: find.byType(Container))
          .first;
      final labelRect = tester.getRect(label);
      final cellRect = tester.getRect(cell);
      // Vertical fit only: the test font (Ahem) is wider than the real one.
      expect(labelRect.top, greaterThanOrEqualTo(cellRect.top));
      expect(labelRect.bottom, lessThanOrEqualTo(cellRect.bottom));
      expect(tester.takeException(), isNull);
    });
  }
}
