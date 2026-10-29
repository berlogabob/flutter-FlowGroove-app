import 'dart:async';

import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/drum_practice_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/metronome_test_runtime.dart';

class _Player implements DrumPlayer {
  final calls = <String>[];
  Completer<void>? pendingLoad;

  @override
  bool playing = false;
  @override
  Stream<int> get stepStream => const Stream.empty();
  @override
  Future<void> load(MidiPattern pattern, double bpm) async {
    calls.add('load');
    await pendingLoad?.future;
  }

  @override
  Future<void> start() async {
    calls.add('start');
    playing = true;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = false;
  }

  @override
  void setLaneGain(DrumLane lane, double gain) => calls.add('gain');
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MetronomeTestRuntime runtime;
  late _Player player;
  late DrumPracticeNotifier drums;
  late MetronomeNotifier click;
  final pattern = MidiPattern(
    name: 'Beat',
    bars: 1,
    beatsPerBar: 4,
    stepsPerBeat: 4,
    hits: const [MidiHit(step: 0, note: 36, vel: 100)],
  );

  Song song(String id) => Song(
    id: id,
    title: id,
    artist: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    runtime = MetronomeTestRuntime();
    player = _Player();
    container = ProviderContainer(
      overrides: [
        ...buildMetronomeTestOverrides(runtime: runtime),
        drumPlayerProvider.overrideWithValue(player),
      ],
    );
    drums = container.read(drumPracticeProvider.notifier);
    click = container.read(metronomeProvider.notifier);
  });

  tearDown(() async {
    click.stop();
    await flush();
    container.dispose();
    await runtime.dispose();
  });

  test(
    'sync defaults on and follows click start and stop in the same frame',
    () async {
      expect(container.read(drumPracticeProvider).syncWithClick, isTrue);
      await drums.loadPattern('entry', pattern);
      player.calls.clear();

      click.start();
      // The listener invokes start synchronously, without a widget/frame pump.
      expect(container.read(drumPracticeProvider).playing, isTrue);
      expect(player.calls, contains('load'));
      await flush();
      expect(player.calls.where((call) => call == 'start'), hasLength(1));
      expect(player.playing, isTrue);

      click.stop();
      expect(container.read(drumPracticeProvider).playing, isFalse);
      expect(player.calls.last, 'stop');
      expect(player.playing, isFalse);
    },
  );

  test('sync off leaves independent drum playback unaffected', () async {
    drums.setSyncWithClick(enabled: false);
    await drums.loadPattern('entry', pattern);
    player.calls.clear();
    click.start();
    await flush();
    expect(player.calls, isEmpty);
    expect(container.read(drumPracticeProvider).playing, isFalse);

    await drums.start();
    player.calls.clear();
    click.stop();
    expect(player.calls, isEmpty);
    expect(player.playing, isTrue);
    await drums.stop();
    expect(player.playing, isFalse);
  });

  test('manual playback works with sync on while click is stopped', () async {
    await drums.loadPattern('entry', pattern);
    await drums.start();
    expect(player.playing, isTrue);
    expect(container.read(metronomeProvider).isPlaying, isFalse);
    await drums.stop();
    expect(player.playing, isFalse);
    expect(container.read(metronomeProvider).isPlaying, isFalse);
  });

  test('no pattern means no player calls', () async {
    click.start();
    await flush();
    click.stop();
    await drums.start();
    await drums.stop();
    drums
      ..toggleMute(DrumLane.kick)
      ..toggleSolo(DrumLane.snare);
    await drums.setSpeed(0.5);
    click
      ..setBpm(150)
      ..loadSongTempo(song('song-1'));
    await flush();
    expect(player.calls, isEmpty);
  });

  test(
    'song changes clear the pattern and cancel a pending drum start',
    () async {
      click.loadSongTempo(song('song-1'));
      drums.setSyncWithClick(enabled: false);
      await drums.loadPattern('entry', pattern);
      final pending = player.pendingLoad = Completer<void>();
      final starting = drums.start();
      click.loadSongTempo(song('song-2'));
      expect(player.calls.last, 'stop');
      expect(container.read(drumPracticeProvider).pattern, isNull);
      expect(container.read(drumPracticeProvider).entryId, isNull);
      expect(container.read(drumPracticeProvider).playing, isFalse);
      expect(container.read(drumPracticeProvider).syncWithClick, isFalse);
      pending.complete();
      await starting;
      expect(player.calls, isNot(contains('start')));
    },
  );

  test('click stop cancels an in-flight drum load', () async {
    await drums.loadPattern('entry', pattern);
    final pending = player.pendingLoad = Completer<void>();
    click
      ..start()
      ..stop();
    pending.complete();
    await flush();
    expect(player.calls, isNot(contains('start')));
    expect(player.playing, isFalse);
  });
}
