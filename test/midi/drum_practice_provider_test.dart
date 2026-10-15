import 'dart:async';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/drum_practice_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestMetronomeNotifier extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial().copyWith(bpm: 120);

  void changeBpm(int bpm) => state = state.copyWith(bpm: bpm);
}

class _FakeDrumPlayer implements DrumPlayer {
  final steps = StreamController<int>.broadcast(sync: true);
  final loads = <(MidiPattern, double)>[];
  final gains = <DrumLane, double>{};
  int startCalls = 0;
  int stopCalls = 0;
  Completer<void>? pendingLoad;
  bool failLoad = false;

  @override
  bool playing = false;

  @override
  Stream<int> get stepStream => steps.stream;

  @override
  Future<void> load(MidiPattern p, double bpm) async {
    loads.add((p, bpm));
    if (failLoad) throw StateError('load failed');
    await pendingLoad?.future;
  }

  @override
  Future<void> start() async {
    ++startCalls;
    playing = true;
  }

  @override
  Future<void> stop() async {
    ++stopCalls;
    playing = false;
  }

  @override
  void setLaneGain(DrumLane lane, double gain) => gains[lane] = gain;

  @override
  Future<void> dispose() async {
    await stop();
    await steps.close();
  }
}

void main() {
  late ProviderContainer container;
  late _FakeDrumPlayer player;
  late _TestMetronomeNotifier metronome;
  late DrumPracticeNotifier notifier;
  late MidiPattern pattern;

  setUp(() {
    player = _FakeDrumPlayer();
    metronome = _TestMetronomeNotifier();
    container = ProviderContainer(
      overrides: [
        drumPlayerProvider.overrideWithValue(player),
        metronomeProvider.overrideWith(() => metronome),
      ],
    );
    notifier = container.read(drumPracticeProvider.notifier);
    pattern = MidiPattern(
      name: 'Rock',
      bars: 1,
      beatsPerBar: 4,
      stepsPerBeat: 4,
      hits: const [MidiHit(step: 0, note: 36, vel: 90)],
    );
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
    });
  });

  void expectGains(Set<DrumLane> audible) {
    expect(player.gains, {
      for (final lane in DrumLane.values) lane: audible.contains(lane) ? 1 : 0,
    });
  }

  test(
    'initial state is empty and starting without a pattern is a no-op',
    () async {
      final state = container.read(drumPracticeProvider);
      expect(state.pattern, isNull);
      expect(state.entryId, isNull);
      expect(state.muted, isEmpty);
      expect(state.solo, isNull);
      expect(state.playing, isFalse);
      expect(state.currentStep, 0);
      expect(state.speed, 1);

      await notifier.start();
      expect(player.loads, isEmpty);
      expect(player.startCalls, 0);
      expect(container.read(drumPracticeProvider).playing, isFalse);
    },
  );

  test('loads the selected entry at metronome BPM times speed', () async {
    await notifier.setSpeed(0.75);
    await notifier.loadPattern('entry-1', pattern);

    final state = container.read(drumPracticeProvider);
    expect(state.entryId, 'entry-1');
    expect(state.pattern, same(pattern));
    expect(player.loads, [(pattern, 90.0)]);
    expectGains(DrumLane.values.toSet());

    await notifier.start();
    expect(player.loads.last, (pattern, 90.0));
    expect(player.playing, isTrue);
    expect(container.read(drumPracticeProvider).playing, isTrue);
    await notifier.start();
    expect(player.startCalls, 1);
  });

  test('mute toggles only its lane and preserves earlier state', () async {
    await notifier.loadPattern('entry-1', pattern);
    await notifier.start();
    final before = container.read(drumPracticeProvider);
    notifier
      ..toggleMute(DrumLane.kick)
      ..toggleMute(DrumLane.snare);
    expect(before.muted, isEmpty);
    expect(container.read(drumPracticeProvider).muted, {
      DrumLane.kick,
      DrumLane.snare,
    });
    expectGains(
      DrumLane.values.toSet()..removeAll({DrumLane.kick, DrumLane.snare}),
    );

    notifier.toggleMute(DrumLane.kick);
    expect(container.read(drumPracticeProvider).muted, {DrumLane.snare});
    expectGains(DrumLane.values.toSet()..remove(DrumLane.snare));
  });

  test(
    'solo overrides mute, switches lanes, and restores mutes when cleared',
    () async {
      await notifier.loadPattern('entry-1', pattern);
      notifier
        ..toggleMute(DrumLane.kick)
        ..toggleSolo(DrumLane.kick);
      expect(container.read(drumPracticeProvider).solo, DrumLane.kick);
      expectGains({DrumLane.kick});

      notifier.toggleMute(DrumLane.snare);
      expectGains({DrumLane.kick});
      notifier.toggleSolo(DrumLane.snare);
      expect(container.read(drumPracticeProvider).solo, DrumLane.snare);
      expectGains({DrumLane.snare});

      notifier.toggleSolo(DrumLane.snare);
      expect(container.read(drumPracticeProvider).solo, isNull);
      expectGains(
        DrumLane.values.toSet()..removeAll({DrumLane.kick, DrumLane.snare}),
      );
    },
  );

  test(
    'BPM changes reload while playing without resetting selection or gains',
    () async {
      await notifier.loadPattern('entry-1', pattern);
      await notifier.setSpeed(0.5);
      notifier.toggleMute(DrumLane.snare);
      await notifier.start();
      final loadCount = player.loads.length;

      metronome.changeBpm(160);
      await Future<void>.delayed(Duration.zero);

      expect(player.loads.length, loadCount + 1);
      expect(player.loads.last, (pattern, 80.0));
      final state = container.read(drumPracticeProvider);
      expect(state.playing, isTrue);
      expect(player.playing, isTrue);
      expect(state.entryId, 'entry-1');
      expect(state.muted, {DrumLane.snare});
      expect(state.speed, 0.5);
      expectGains(DrumLane.values.toSet()..remove(DrumLane.snare));
    },
  );

  test(
    'follows song tempo and defers stopped BPM changes until start',
    () async {
      final now = DateTime(2026);
      metronome.loadSongTempo(
        Song(
          id: 'song-1',
          title: 'Song',
          artist: '',
          originalBPM: 180,
          ourBPM: 140,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await notifier.loadPattern('entry-1', pattern);
      final loadCount = player.loads.length;
      metronome.changeBpm(150);
      await Future<void>.delayed(Duration.zero);
      expect(player.loads.length, loadCount);

      await notifier.start();
      expect(player.loads.last, (pattern, 150.0));
      final playingLoads = player.loads.length;
      metronome.setVolume(0.25);
      await Future<void>.delayed(Duration.zero);
      expect(player.loads.length, playingLoads);
    },
  );

  test(
    'speed changes reload a playing pattern and reject invalid speeds',
    () async {
      await notifier.loadPattern('entry-1', pattern);
      await notifier.start();
      final loadCount = player.loads.length;
      await notifier.setSpeed(0.75);
      expect(player.loads.length, loadCount + 1);
      expect(player.loads.last, (pattern, 90.0));
      expect(container.read(drumPracticeProvider).playing, isTrue);

      await notifier.setSpeed(0.75);
      expect(player.loads.length, loadCount + 1);
      for (final speed in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(notifier.setSpeed(speed), throwsArgumentError);
      }
      expect(container.read(drumPracticeProvider).speed, 0.75);
      expect(player.loads.length, loadCount + 1);
    },
  );

  test('stop resets the step and ignores late player steps', () async {
    await notifier.loadPattern('entry-1', pattern);
    await notifier.start();
    player.steps.add(7);
    expect(container.read(drumPracticeProvider).currentStep, 7);

    await notifier.stop();
    expect(player.stopCalls, 1);
    expect(player.playing, isFalse);
    expect(container.read(drumPracticeProvider).playing, isFalse);
    expect(container.read(drumPracticeProvider).currentStep, 0);
    player.steps.add(8);
    expect(container.read(drumPracticeProvider).currentStep, 0);
  });

  test('stop during a pending load prevents a late start', () async {
    await notifier.loadPattern('entry-1', pattern);
    final pending = player.pendingLoad = Completer<void>();
    final starting = notifier.start();
    await notifier.stop();
    pending.complete();
    await starting;

    expect(player.startCalls, 0);
    expect(player.playing, isFalse);
    expect(container.read(drumPracticeProvider).playing, isFalse);
    expect(container.read(drumPracticeProvider).currentStep, 0);
  });

  test('a failed load leaves playback stopped', () async {
    await notifier.loadPattern('entry-1', pattern);
    player.failLoad = true;
    await notifier.start();

    expect(player.startCalls, 0);
    expect(player.playing, isFalse);
    expect(container.read(drumPracticeProvider).playing, isFalse);
    expect(container.read(drumPracticeProvider).currentStep, 0);
  });
}
