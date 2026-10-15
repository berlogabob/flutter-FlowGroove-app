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
          home: Scaffold(body: DrumGridEditor(songId: 'song', dirty: dirty)),
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

  testWidgets('lane labels stay fixed while compact grouped steps scroll', (
    tester,
  ) async {
    await open(tester);
    final scroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    const labels = [
      'Kick',
      'Snare',
      'Closed hat',
      'Open hat',
      'High tom',
      'Mid tom',
      'Floor tom',
      'Crash',
      'Ride',
    ];
    final positions = [
      for (final label in labels) tester.getTopLeft(find.text(label)),
    ];
    for (final label in labels) {
      expect(
        find.descendant(of: scroll, matching: find.text(label)),
        findsNothing,
      );
    }
    expect(tester.getSize(cell(0)), const Size(36, 48));
    expect(
      tester.getRect(cell(7)).left,
      lessThan(tester.getRect(scroll).right),
    );
    expect(
      tester.getRect(cell(4)).left - tester.getRect(cell(3)).right,
      greaterThan(0),
    );
    expect(
      tester.widget<Text>(find.text('5')).style!.fontWeight,
      FontWeight.bold,
    );
    final before = tester.getTopLeft(cell(0));
    await tester.drag(scroll, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(cell(0)).dx, lessThan(before.dx));
    for (var i = 0; i < labels.length; i++) {
      expect(tester.getTopLeft(find.text(labels[i])), positions[i]);
    }
    final semantics = tester.ensureSemantics();
    await tester.tap(cell(15));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(cell(15)).value, 'Normal (90)');
    semantics.dispose();
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
