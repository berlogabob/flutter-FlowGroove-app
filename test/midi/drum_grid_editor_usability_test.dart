import 'dart:async';

import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/providers/data/drum_practice_provider.dart';
import 'package:flowgroove/screens/songs/components/drum_grid_editor.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/metronome_test_runtime.dart';

class _Player implements DrumPlayer {
  final steps = StreamController<int>.broadcast();
  MidiPattern? pattern;

  @override
  bool playing = false;
  @override
  Stream<int> get stepStream => steps.stream;
  @override
  Future<void> load(MidiPattern p, double bpm) async => pattern = p;
  @override
  Future<void> start() async => playing = true;
  @override
  Future<void> stop() async => playing = false;
  @override
  void setLaneGain(DrumLane lane, double gain) {}
  @override
  Future<void> dispose() async => steps.close();
}

void main() {
  late ProviderContainer container;
  late MetronomeTestRuntime runtime;
  late _Player player;
  late ValueNotifier<bool> dirty;

  setUp(() {
    runtime = MetronomeTestRuntime();
    player = _Player();
    dirty = ValueNotifier(false);
    container = ProviderContainer(
      overrides: [
        ...runtime.overrides,
        drumPlayerProvider.overrideWithValue(player),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await runtime.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: DrumGridEditor(songId: 'song', dirty: dirty),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder cell(int step) => find.byKey(ValueKey('drum-cell-kick-$step'));
  Finder column(int step) => find.byKey(ValueKey('drum-step-$step'));

  testWidgets('first tap is normal, then accent, ghost and off on a phone', (
    tester,
  ) async {
    await open(tester);
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(cell(0)).value, 'Off (0)');
    expect(
      find.text('Tap: Off → Normal (90) → Accent (120) → Ghost (40) → Off'),
      findsOneWidget,
    );

    for (final (label, velocity) in [
      ('Normal', 90),
      ('Accent', 120),
      ('Ghost', 40),
      ('Off', 0),
    ]) {
      await tester.tap(cell(0));
      await tester.pumpAndSettle();
      expect(dirty.value, isTrue);
      expect(tester.getSemantics(cell(0)).value, '$label ($velocity)');
      await tester.ensureVisible(find.text('Play'));
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(
        player.pattern!.hits.map((hit) => hit.vel),
        velocity == 0 ? isEmpty : orderedEquals([velocity]),
      );
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
    }
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('steps are shown 8 per page and page chips switch the page', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('drum-step-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('drum-step-8')), findsNothing);
    expect(find.text('Kick'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drum-page-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drum-step-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('drum-step-7')), findsNothing);
    expect(find.text('Kick'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview highlight follows currentStep and clears on stop', (
    tester,
  ) async {
    await open(tester);
    Color? color(int step) => tester.widget<Container>(column(step)).color;
    expect(color(0), isNull);
    await tester.ensureVisible(find.text('Play'));
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    final highlight = Theme.of(
      tester.element(column(0)),
    ).colorScheme.secondaryContainer;
    expect(color(0), highlight);
    expect(color(4), isNull);
    player.steps.add(4);
    await tester.pumpAndSettle();
    expect(container.read(drumPracticeProvider).currentStep, 4);
    expect(color(0), isNull);
    expect(color(4), highlight);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(color(0), isNull);
    expect(color(4), isNull);
    player.steps.add(2);
    await tester.pumpAndSettle();
    expect(color(2), isNull);
    expect(tester.takeException(), isNull);
  });
}
