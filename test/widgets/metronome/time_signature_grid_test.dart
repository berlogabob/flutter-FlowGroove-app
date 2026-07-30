// The Beats and Subdivision strips must tile on ONE column grid.
//
// Each strip used to size its cells `availableWidth / count` from its OWN row's
// count, so a 4-beat row and a 1-subdivision row produced different cell widths
// AND different spaceEvenly offsets — the 3-4px "alignment near-misses" the
// 2026-07-18 Android audit measured (F-019, issue #171).
//
// This is the check that actually catches a regression: the audit's evidence was
// a screenshot and a measurements.json, neither of which CI can assert on.
//
// No `theme:` on the MaterialApp on purpose — MonoPulseTheme.theme calls
// GoogleFonts.interTextTheme(), which throws under flutter_test (same reason
// mono_pulse_scheme_test.dart goes through schemeFor).

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/widgets/metronome/time_signature_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestMetronomeNotifier extends MetronomeNotifier {
  TestMetronomeNotifier(this.initialState);

  final MetronomeState initialState;

  @override
  MetronomeState build() => initialState;
}

void main() {
  Widget build({required int beats, required int subdivisions}) {
    final state = MetronomeState.initial().copyWith(
      accentBeats: beats,
      regularBeats: subdivisions,
    );
    return ProviderScope(
      overrides: [
        metronomeProvider.overrideWith(() => TestMetronomeNotifier(state)),
      ],
      child: const MaterialApp(home: Scaffold(body: TimeSignatureBlock())),
    );
  }

  group('Beats / Subdivision share one column grid (F-019)', () {
    // 4 beats over 1 subdivision is the exact case the audit screenshotted.
    testWidgets('column 0 starts at the same x in both rows', (tester) async {
      await tester.pumpWidget(build(beats: 4, subdivisions: 1));
      await tester.pumpAndSettle();

      final beat = tester
          .getTopLeft(find.byKey(const Key('main_beat_dot_0')))
          .dx;
      final sub = tester
          .getTopLeft(find.byKey(const Key('subdivision_dot_0')))
          .dx;

      // Exactly equal, not "within 4px" — an approximate assertion would have
      // passed on the very bug it exists to catch.
      expect(sub, beat);
    });

    testWidgets('cells are the same width in both rows', (tester) async {
      await tester.pumpWidget(build(beats: 4, subdivisions: 1));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('subdivision_dot_0'))).width,
        tester.getSize(find.byKey(const Key('main_beat_dot_0'))).width,
      );
    });

    testWidgets('every shared column lines up when both rows are populated', (
      tester,
    ) async {
      await tester.pumpWidget(build(beats: 4, subdivisions: 3));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        expect(
          tester.getTopLeft(find.byKey(Key('subdivision_dot_$i'))).dx,
          tester.getTopLeft(find.byKey(Key('main_beat_dot_$i'))).dx,
          reason: 'column $i is off the shared grid',
        );
      }
    });

    // The grid is driven by max(beats, subdivisions), so it must hold when the
    // SUBDIVISION row is the longer one too — not just beats-longer.
    testWidgets('holds when subdivisions outnumber beats', (tester) async {
      await tester.pumpWidget(build(beats: 2, subdivisions: 6));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('subdivision_dot_1'))).dx,
        tester.getTopLeft(find.byKey(const Key('main_beat_dot_1'))).dx,
      );
    });

    // F-006 raised the tap target to >=48dp; a shared grid shrinks cell WIDTH,
    // so the height guarantee has to survive the change.
    testWidgets('tap target stays >=48dp tall at the 12-beat maximum', (
      tester,
    ) async {
      await tester.pumpWidget(build(beats: 12, subdivisions: 1));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('main_beat_dot_0'))).height,
        greaterThanOrEqualTo(48),
      );
    });

    // MUST run at phone width. On the default 800x600 test surface every cell
    // clamps to _kMaxCircleContainer (48) no matter what count it was computed
    // from, so a row sizing cells from its OWN count looks identical and the
    // regression slips through — verified: this suite passed with the shared
    // grid reverted until this case existed. At 360dp the 12-beat row falls
    // below the clamp and a per-row count would give it ~17px cells against the
    // subdivision row's 48px.
    testWidgets('cell width is shared even when the clamp is not in play', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(build(beats: 12, subdivisions: 1));
      await tester.pumpAndSettle();

      final beat = tester.getSize(find.byKey(const Key('main_beat_dot_0')));
      final sub = tester.getSize(find.byKey(const Key('subdivision_dot_0')));

      expect(
        beat.width,
        lessThan(48),
        reason: 'guard is pointless if the clamp still applies at this width',
      );
      expect(sub.width, beat.width);
      expect(
        tester.getTopLeft(find.byKey(const Key('subdivision_dot_0'))).dx,
        tester.getTopLeft(find.byKey(const Key('main_beat_dot_0'))).dx,
      );
    });
  });
}
