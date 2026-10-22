import 'dart:async';

import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/drum_practice_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backing_transport_test.dart'
    show FakeBackingEngine, FakeMetronome, entry, song;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBackingEngine engine;
  late FakeMetronome metro;
  late ProviderContainer container;
  late DrumPracticeNotifier drums;
  final pattern = MidiPattern(
    name: 'Rock',
    bars: 2,
    beatsPerBar: 4,
    stepsPerBeat: 4,
    hits: const [MidiHit(step: 0, note: 36, vel: 100)],
  );
  final sections = [Section(id: 'verse', name: 'Verse', duration: 4)];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    engine = FakeBackingEngine();
    metro = FakeMetronome();
    container = ProviderContainer(
      overrides: [
        backingEngineProvider.overrideWithValue(engine),
        metronomeProvider.overrideWith(() => metro),
        midiSongProvider.overrideWith((ref, entry) async => song),
      ],
    );
    drums = container.read(drumPracticeProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await engine.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'two-bar pattern loads one engine-rate stem and launches a loop',
    () async {
      await drums.loadPattern('pattern', pattern);
      final stems = engine.loads.single;
      expect(stems.names, ['Drums']);
      expect(stems.stems, hasLength(1));
      expect(stems.sampleRate, 8000);
      expect(stems.stems.single, hasLength(32000));
      expect(stems.stems.single.any((sample) => sample != 0), isTrue);

      await drums.start();
      final launch = engine.commands.single;
      expect(launch.kind, BackingKind.launch);
      expect(launch.fromBar, 0);
      expect(launch.bars, 2);
      expect(launch.loop, isTrue);
      expect(launch.atBar, 2);
      await drums.stop();
      expect(engine.commands.last.kind, BackingKind.stop);
    },
  );

  test('MIDI selection clears and stops the pattern', () async {
    await drums.loadPattern('pattern', pattern);
    await drums.start();
    final transport = container.read(backingTransportProvider.notifier);
    await transport.attach(entry(), sections);
    final state = container.read(drumPracticeProvider);
    expect(state.pattern, isNull);
    expect(state.entryId, isNull);
    expect(state.playing, isFalse);
    expect(engine.commands.last.kind, BackingKind.stop);
    expect(engine.loads.last.names, contains('Bass'));
    await transport.launch('verse');
    expect(engine.commands.last.bars, 4);
  });

  test(
    'pattern selection replaces MIDI and detaches its tempo reload',
    () async {
      final transport = container.read(backingTransportProvider.notifier);
      await transport.attach(entry(), sections);
      await transport.launch('verse');
      engine.playing(engine.commands.last);
      await drums.loadPattern('pattern', pattern);
      expect(container.read(backingTransportProvider).playingId, isNull);
      expect(engine.calls.skip(engine.calls.length - 2), ['clear', 'load']);
      await transport.launch('verse');
      expect(engine.commands, hasLength(1));
      final loads = engine.loads.length;
      metro.tempo(140);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(engine.loads, hasLength(loads));
    },
  );

  test(
    'slow patterns are padded to whole bars and lane mute rerenders',
    () async {
      await drums.setSpeed(0.75);
      await drums.loadPattern('pattern', pattern);
      expect(engine.loads.single.stems.single, hasLength(48000));
      expect(engine.loads.single.renderBpm, 120);
      await drums.start();
      expect(engine.commands.last.bars, 3);
      drums.toggleMute(DrumLane.kick);
      await Future<void>.delayed(Duration.zero);
      expect(
        engine.loads.last.stems.single.every((sample) => sample == 0),
        isTrue,
      );
      await drums.stop();
    },
  );

  test('rounded tick intervals do not add a bar at another tempo', () async {
    metro.tempo(140);
    await drums.loadPattern('pattern', pattern);
    await drums.start();
    expect(engine.commands.last.bars, 2);
    expect(engine.loads.last.stems.single, hasLength(27429));
    await drums.stop();
  });

  test('stop during a pending pattern start prevents a launch', () async {
    await drums.loadPattern('pattern', pattern);
    engine.loadGate = Completer<void>();
    final starting = drums.start();
    while (engine.loads.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    await drums.stop();
    engine.loadGate!.complete();
    await starting;
    expect(container.read(drumPracticeProvider).playing, isFalse);
    expect(engine.commands.where((c) => c.kind == BackingKind.launch), isEmpty);
  });

  test('MIDI selection wins over a pending pattern load', () async {
    engine.loadGate = Completer<void>();
    final loading = drums.loadPattern('pattern', pattern);
    while (engine.loads.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final attaching = container
        .read(backingTransportProvider.notifier)
        .attach(entry(), sections);
    engine.loadGate!.complete();
    await Future.wait([loading, attaching]);
    expect(container.read(drumPracticeProvider).pattern, isNull);
    expect(engine.loads.last.names, contains('Bass'));
    expect(engine.commands.where((c) => c.kind == BackingKind.launch), isEmpty);
  });
}
