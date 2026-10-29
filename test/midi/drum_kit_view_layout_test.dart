import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/widgets/midi/drum_kit_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pattern = MidiPattern(
    name: 't',
    bars: 1,
    beatsPerBar: 4,
    stepsPerBeat: 4,
    hits: [
      for (final n in [36, 38, 42, 46, 48, 45, 41, 49, 51])
        MidiHit(step: 0, note: n, vel: 100),
    ],
  );

  for (final size in const [Size(360, 800), Size(320, 640)]) {
    testWidgets('lane rows fit width at $size, no overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DrumKitView(
                currentStep: 0,
                pattern: pattern,
                muted: const {},
                solo: null,
                onToggleMute: (_) {},
                onToggleSolo: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final lane in DrumLane.values) {
        final s = tester.getRect(find.byKey(ValueKey('S-${lane.name}')));
        expect(s.right, lessThanOrEqualTo(size.width));
        expect(s.left, greaterThanOrEqualTo(0));
      }
    });
  }
}
