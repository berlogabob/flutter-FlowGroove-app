import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/widgets/midi/drum_kit_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pattern = MidiPattern(
    name: 'Beat',
    bars: 2,
    beatsPerBar: 4,
    stepsPerBeat: 4,
    hits: const [
      MidiHit(step: 0, note: 36, vel: 100),
      MidiHit(step: 31, note: 35, vel: 90),
      MidiHit(step: 1, note: 38, vel: 80),
      MidiHit(step: 0, note: 42, vel: 0),
      MidiHit(step: 0, note: 60, vel: 100),
    ],
  );

  Future<void> pumpView(
    WidgetTester tester, {
    int step = 0,
    MidiPattern? value,
    Set<DrumLane> muted = const {},
    DrumLane? solo,
    ValueChanged<DrumLane>? onMute,
    ValueChanged<DrumLane>? onSolo,
    double width = 400,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: DrumKitView(
              currentStep: step,
              pattern: value ?? pattern,
              muted: muted,
              solo: solo,
              onToggleMute: onMute ?? (_) {},
              onToggleSolo: onSolo ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  DrumKitPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(const Key('drum-kit'))).painter!
          as DrumKitPainter;

  BoxDecoration dot(WidgetTester tester, String lane, int offset) =>
      tester
              .widget<Container>(find.byKey(ValueKey('dot-$lane-$offset')))
              .decoration!
          as BoxDecoration;

  testWidgets('renders only used lanes with 16 dots and wraps the preview', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpView(tester, step: 31);

    expect(find.byKey(const Key('lane-kick')), findsOneWidget);
    expect(find.byKey(const Key('lane-snare')), findsOneWidget);
    expect(find.byKey(const Key('lane-hatClosed')), findsNothing);
    expect(find.byType(FilterChip), findsNWidgets(4));
    for (final lane in ['kick', 'snare']) {
      for (var i = 0; i < 16; i++) {
        expect(find.byKey(ValueKey('dot-$lane-$i')), findsOneWidget);
      }
      expect(find.byKey(ValueKey('dot-$lane-16')), findsNothing);
    }
    final colors = Theme.of(
      tester.element(find.byType(DrumKitView)),
    ).colorScheme;
    expect(dot(tester, 'kick', 0).color, colors.primary);
    expect(dot(tester, 'kick', 1).color, colors.primary);
    expect(dot(tester, 'snare', 2).color, colors.primary);
    expect(dot(tester, 'snare', 1).color, isNull);
    expect(dot(tester, 'snare', 0).border!.top.color, colors.tertiary);
    expect(find.bySemanticsLabel('Kick step 32'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('M/S chips have 48dp targets and report the correct lane', (
    tester,
  ) async {
    final muted = <DrumLane>[];
    final soloed = <DrumLane>[];
    await pumpView(tester, onMute: muted.add, onSolo: soloed.add);
    for (final lane in [DrumLane.kick, DrumLane.snare]) {
      for (final label in ['M', 'S']) {
        final chip = find.byKey(ValueKey('$label-${lane.name}'));
        final size = tester.getSize(chip);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        await tester.tap(chip);
      }
    }
    expect(muted, [DrumLane.kick, DrumLane.snare]);
    expect(soloed, [DrumLane.kick, DrumLane.snare]);

    await pumpView(tester, muted: {DrumLane.kick}, solo: DrumLane.snare);
    expect(
      tester.widget<FilterChip>(find.byKey(const Key('M-kick'))).selected,
      isTrue,
    );
    expect(
      tester.widget<FilterChip>(find.byKey(const Key('S-snare'))).selected,
      isTrue,
    );
    expect(
      tester.widget<FilterChip>(find.byKey(const Key('S-kick'))).selected,
      isFalse,
    );
  });

  testWidgets('step changes trigger a flash that decays in 120ms', (
    tester,
  ) async {
    await pumpView(tester);
    expect(painter(tester).active, {DrumLane.kick});
    expect(painter(tester).flash, 1);
    final kit = find.byKey(const Key('drum-kit'));
    final height = tester.getSize(kit).height;
    expect(
      kit,
      paints..circle(
        radius: height * 0.17 * 1.15,
        color: painter(tester).colors.primary,
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(painter(tester).flash, closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 60));
    expect(painter(tester).flash, 0);
    expect(
      kit,
      paints..circle(
        radius: height * 0.17,
        color: painter(tester).colors.surfaceContainerHigh,
      ),
    );

    await pumpView(tester, step: 1);
    expect(painter(tester).active, {DrumLane.snare});
    expect(painter(tester).flash, 1);
    expect(dot(tester, 'snare', 0).color, isNotNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(painter(tester).flash, 0);
    await pumpView(tester, step: 2);
    expect(painter(tester).active, isEmpty);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and zero-length patterns render at narrow widths', (
    tester,
  ) async {
    for (final bars in [1, 0]) {
      await pumpView(
        tester,
        width: 280,
        value: MidiPattern(
          name: 'Empty',
          bars: bars,
          beatsPerBar: 4,
          stepsPerBeat: 4,
          hits: const [],
        ),
      );
      expect(find.byKey(const Key('drum-kit')), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(painter(tester).active, isEmpty);
      expect(tester.takeException(), isNull);
    }
    await pumpView(tester, width: 280);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
