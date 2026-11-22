import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/tuner/transport_bar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Tuner extends TunerNotifier {
  _Tuner({this.initialMode = TunerMode.listen});

  final TunerMode initialMode;

  @override
  TunerState build() => TunerState(mode: initialMode);

  void setTransportState({bool playing = false, bool starting = false}) {
    state = state.copyWith(isPlaying: playing, isStarting: starting);
  }
}

void main() {
  testWidgets('transport keeps the same slots while starting and playing', (
    tester,
  ) async {
    final tuner = _Tuner(initialMode: TunerMode.generate);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tunerProvider.overrideWith(() => tuner)],
        child: const MaterialApp(home: Scaffold(body: TransportBar())),
      ),
    );
    final action = find.byType(AnimatedContainer);
    final calibration = find.text('A4 440');
    final actionRect = tester.getRect(action);
    final calibrationRect = tester.getRect(calibration);
    expect(actionRect.width, 80);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    tuner.setTransportState(starting: true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getRect(action), actionRect);
    expect(tester.getRect(calibration), calibrationRect);

    tuner.setTransportState(playing: true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(tester.getRect(action), actionRect);
    expect(tester.getRect(calibration), calibrationRect);
  });

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
