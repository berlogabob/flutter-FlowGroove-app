import 'dart:async';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/section_span.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flowgroove/utils/pad_state.dart';
import 'package:flowgroove/utils/play_mode.dart';
import 'package:flowgroove/utils/quantize.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMetronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial().copyWith(countInBars: 2);

  @override
  void start() => state = state.copyWith(isPlaying: true, completedBars: 0);

  @override
  void stop() => state = state.copyWith(isPlaying: false);

  void tempo(int bpm) => state = state.copyWith(bpm: bpm);
}

class FakeBackingEngine implements BackingEngine {
  final events = StreamController<BackingState>.broadcast(sync: true);
  final barEvents = StreamController<int>.broadcast(sync: true);
  final commands = <BackingCommand>[];
  final loads = <BackingStems>[];
  final calls = <String>[];
  final gains = <int, double>{};
  Completer<void>? loadGate;

  @override
  Stream<BackingState> get states => events.stream;
  @override
  Stream<int> get bars => barEvents.stream;
  @override
  Future<int> engineSampleRate() async => 8000;
  @override
  Future<void> load(BackingStems stems) async {
    calls.add('load');
    loads.add(stems);
    await loadGate?.future;
  }

  @override
  Future<void> command(BackingCommand c) async {
    commands.add(c);
    events.add(BackingState(c.token, BackingStateKind.queued, c.atBar));
  }

  void stopped(BackingCommand c) =>
      events.add(BackingState(c.token, BackingStateKind.stopped, c.atBar));

  void playing(BackingCommand c) =>
      events.add(BackingState(c.token, BackingStateKind.playing, c.atBar));

  @override
  void setGain(int stem, double gain) => gains[stem] = gain;
  @override
  Future<void> clear() async => calls.add('clear');
  @override
  Future<void> dispose() async {
    await events.close();
    await barEvents.close();
  }
}

const song = MidiSongData(
  ppq: 480,
  tempos: [TempoChange(tick: 0, microsPerQuarter: 500000)],
  timeSigs: [],
  tracks: [
    MidiTrackData(
      index: 0,
      name: 'Bass',
      channel: 0,
      program: 33,
      notes: [MidiNote(tick: 0, dur: 480, pitch: 40, vel: 100)],
    ),
    MidiTrackData(
      index: 1,
      name: 'Drums',
      channel: 9,
      program: 0,
      notes: [MidiNote(tick: 0, dur: 480, pitch: 36, vel: 100)],
    ),
  ],
);

SongLabEntry entry({
  bool fileTempo = false,
  List<SectionSpan> spans = const [],
}) => SongLabEntry(
  id: 'midi',
  songId: 'song',
  type: LabEntryType.midi,
  authorId: 'author',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  midiSong: MidiSongMeta(
    ppq: 480,
    initialBpm: 120,
    tracks: const [],
    sectionMap: spans,
    useFileTempo: fileTempo,
  ),
);

void main() {
  late FakeBackingEngine engine;
  late FakeMetronome metro;
  late ProviderContainer container;
  late BackingTransportNotifier transport;
  final sections = [
    Section(id: 'verse', name: 'Verse', duration: 4),
    Section(id: 'chorus', name: 'Chorus', duration: 8),
  ];

  setUp(() {
    engine = FakeBackingEngine();
    metro = FakeMetronome();
    container = ProviderContainer(
      overrides: [
        backingEngineProvider.overrideWithValue(engine),
        metronomeProvider.overrideWith(() => metro),
        midiSongProvider.overrideWith((ref, entry) async => song),
      ],
    );
    transport = container.read(backingTransportProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await engine.dispose();
  });

  group('play modes and block quantize', () {
    Future<BackingCommand> launched(String id) async {
      await transport.launch(id);
      return engine.commands.last;
    }

    test('once plays only the launched section, no loop', () async {
      await transport.attach(entry(), sections);
      transport.setMode(PlayMode.once);
      final command = await launched('verse');
      expect((command.fromBar, command.bars, command.loop), (0, 4, false));
    });

    test('a finished Once run stops the click, a loop does not end', () async {
      await transport.attach(entry(), sections);
      transport.setMode(PlayMode.once);
      final command = await launched('verse');
      engine.playing(command);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(metronomeProvider).isPlaying, isTrue);
      engine.stopped(command);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(backingTransportProvider).playingId, isNull);
      expect(container.read(metronomeProvider).isPlaying, isFalse);
    });

    test('loop repeats the launched section', () async {
      await transport.attach(entry(), sections);
      transport.setMode(PlayMode.loop);
      final command = await launched('chorus');
      expect((command.fromBar, command.bars, command.loop), (4, 8, true));
    });

    test('song runs from the launched section to the end, once', () async {
      await transport.attach(entry(), sections);
      transport.setMode(PlayMode.song);
      final first = await launched('verse');
      expect((first.fromBar, first.bars, first.loop), (0, 12, false));
      final second = await launched('chorus');
      expect((second.fromBar, second.bars, second.loop), (4, 8, false));
    });

    test(
      'switching to Loop mid-song finishes the section, then loops it',
      () async {
        await transport.attach(entry(), sections);
        transport.setMode(PlayMode.song);
        final run = await launched('verse');
        engine.playing(run);
        engine.barEvents.add(run.atBar + 1);
        final before = engine.commands.length;
        transport.setMode(PlayMode.loop);
        final rest = engine.commands[before];
        final loop = engine.commands[before + 1];
        final pos = rest.atBar - run.atBar;
        expect((rest.fromBar, rest.bars, rest.loop), (pos, 4 - pos, false));
        expect((loop.fromBar, loop.bars, loop.loop), (0, 4, true));
        expect(loop.atBar, rest.atBar + rest.bars);
        // The handed-over pass ending must not take the click with it.
        engine.stopped(rest);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(metronomeProvider).isPlaying, isTrue);
      },
    );

    test(
      'switching to Song or Once mid-loop continues from the exact bar',
      () async {
        await transport.attach(entry(), sections);
        transport.setMode(PlayMode.loop);
        final run = await launched('chorus');
        engine.playing(run);
        engine.barEvents.add(run.atBar + 1);
        var before = engine.commands.length;
        transport.setMode(PlayMode.song);
        final song = engine.commands[before];
        expect(song.loop, isFalse);
        expect(song.fromBar, 4 + song.atBar - run.atBar);
        expect(song.fromBar + song.bars, 12);
        before = engine.commands.length;
        transport.setMode(PlayMode.once);
        final once = engine.commands[before];
        expect(once.loop, isFalse);
        expect(once.fromBar + once.bars, 12);
      },
    );

    test('a song run highlights the section being played', () async {
      await transport.attach(entry(), sections);
      transport.setMode(PlayMode.song);
      final command = await launched('verse');
      engine.playing(command);
      expect(container.read(backingTransportProvider).playingId, 'verse');
      engine.barEvents.add(command.atBar + 3);
      expect(container.read(backingTransportProvider).playingId, 'verse');
      engine.barEvents.add(command.atBar + 4);
      expect(container.read(backingTransportProvider).playingId, 'chorus');
      expect(container.read(backingTransportProvider).songBar, 4);
    });

    test('block waits for the playing loop pass to finish', () async {
      await transport.attach(entry(), sections);
      transport.setMode(PlayMode.loop);
      final verse = await launched('verse');
      engine.playing(verse);
      engine.barEvents.add(verse.atBar + 1);
      transport.setQuantize(Quantize.block);
      final chorus = await launched('chorus');
      expect(chorus.atBar, verse.atBar + 4);
      // A later bar in the second pass ends at the second pass boundary.
      engine.barEvents.add(verse.atBar + 5);
      final again = await launched('verse');
      expect(again.atBar, verse.atBar + 8);
    });

    test('block in a song run ends at the current section', () async {
      await transport.attach(entry(), sections);
      transport.setMode(PlayMode.song);
      final verse = await launched('verse');
      engine.playing(verse);
      engine.barEvents.add(verse.atBar + 5); // inside the chorus (bars 4..11)
      transport.setQuantize(Quantize.block);
      final next = await launched('verse');
      expect(next.atBar, verse.atBar + 12);
    });

    test('changing quantize re-times a queued launch', () async {
      await transport.attach(entry(), sections);
      transport.setQuantize(Quantize.bar);
      final first = await launched('verse');
      engine.playing(first);
      engine.barEvents.add(first.atBar + 1);
      transport.setQuantize(Quantize.block);
      final queued = await launched('chorus');
      final before = engine.commands.length;
      transport.setQuantize(Quantize.bar);
      final added = engine.commands.sublist(before);
      expect(added.first.kind, BackingKind.cancel);
      expect(added.first.fromBar, queued.token);
      expect(added.last.kind, BackingKind.launch);
      expect(added.last.fromBar, 4);
      expect(added.last.atBar, lessThan(queued.atBar));
    });

    test('block with nothing playing starts at the next bar', () async {
      await transport.attach(entry(), sections);
      transport.setQuantize(Quantize.block);
      final first = await launched('verse');
      expect(first.atBar, 2); // count-in
    });
  });

  test('stopped launch starts metronome and respects count-in', () async {
    await transport.attach(entry(), sections);
    transport
      ..setMode(PlayMode.once)
      ..setQuantize(Quantize.beat);
    await transport.launch('chorus');
    final command = engine.commands.single;
    expect(container.read(metronomeProvider).isPlaying, isTrue);
    expect(command.kind, BackingKind.launch);
    expect(command.atBar, 2);
    expect(command.fromBar, 4);
    expect(command.bars, 8);
    expect(command.loop, isFalse);
    expect(container.read(backingTransportProvider).quantize, Quantize.beat);
  });

  test(
    'playing launch remains queued until engine confirms playback',
    () async {
      await transport.attach(entry(), sections);
      await transport.launch('verse');
      engine.playing(engine.commands.last);
      engine.barEvents.add(5);
      await transport.launch('chorus');
      final command = engine.commands.last;
      expect(command.atBar, 6);
      var state = container.read(backingTransportProvider);
      expect(state.playingId, 'verse');
      expect(state.queuedId, 'chorus');
      expect(state.padState('chorus'), PadState.queued);
      engine.playing(command);
      state = container.read(backingTransportProvider);
      expect(state.playingId, 'chorus');
      expect(state.queuedId, isNull);
      engine.barEvents.add(7);
      expect(container.read(backingTransportProvider).songBar, 5);
    },
  );

  test(
    'a second tempo change while the resume is still queued keeps it',
    () async {
      await transport.attach(entry(), sections);
      await transport.launch('verse');
      engine.playing(engine.commands.last);
      engine.barEvents.add(3);
      metro.tempo(130);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(container.read(backingTransportProvider).queuedId, 'verse');
      metro.tempo(135);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(container.read(backingTransportProvider).queuedId, 'verse');
      expect(engine.loads.last.renderBpm, 135);
    },
  );

  test('tempo changes clear, debounce, reload and resume next bar', () async {
    await transport.attach(entry(), sections);
    await transport.launch('verse');
    final previous = engine.commands.last;
    engine.playing(previous);
    engine.barEvents.add(3);
    metro.tempo(130);
    expect(container.read(backingTransportProvider).rendering, isTrue);
    expect(container.read(backingTransportProvider).playingId, isNull);
    engine.playing(previous);
    await transport.launch('chorus');
    expect(engine.commands, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(engine.calls.last, 'clear');
    metro.tempo(140);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(engine.loads, hasLength(2));
    expect(engine.calls, ['clear', 'load', 'clear', 'clear', 'load']);
    expect(engine.loads.last.renderBpm, 140);
    expect(engine.commands.last.atBar, 4);
    expect(container.read(backingTransportProvider).playingId, isNull);
    expect(container.read(backingTransportProvider).queuedId, 'verse');
    engine.playing(engine.commands.last);
    expect(container.read(backingTransportProvider).playingId, 'verse');
  });

  test(
    'rendering lasts until load finishes and blocks audible state',
    () async {
      engine.loadGate = Completer<void>();
      final attaching = transport.attach(entry(), sections);
      while (engine.loads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(backingTransportProvider).rendering, isTrue);
      await transport.launch('verse');
      engine.events.add(const BackingState(1, BackingStateKind.playing, 0));
      expect(engine.commands, isEmpty);
      expect(container.read(backingTransportProvider).playingId, isNull);
      expect(container.read(metronomeProvider).isPlaying, isFalse);
      engine.loadGate!.complete();
      await attaching;
      expect(container.read(backingTransportProvider).rendering, isFalse);
    },
  );

  test('minus-one, mute and solo set gains by stem role', () async {
    await transport.attach(entry(), sections);
    final bass = engine.loads.single.names.indexOf('Bass');
    final drums = engine.loads.single.names.indexOf('Drums');
    transport.minusOne('Bass');
    expect(engine.gains[bass], 0);
    expect(engine.gains[drums], 1);
    transport
      ..muteStem('Bass', mute: false)
      ..soloStem('Bass');
    expect(engine.gains[bass], 1);
    expect(engine.gains[drums], 0);
    transport.soloStem('Bass', solo: false);
    expect(engine.gains[drums], 1);
  });

  test('uses mapped spans and file tempo when requested', () async {
    metro.tempo(90);
    const span = SectionSpan(sectionId: 'verse', startBar: 2, bars: 3);
    await transport.attach(entry(fileTempo: true, spans: [span]), sections);
    expect(engine.loads.single.renderBpm, 120);
    expect(container.read(backingTransportProvider).spans, [span]);
    await transport.launch('verse');
    expect(engine.commands.single.fromBar, 2);
    expect(engine.commands.single.bars, 3);
  });

  test(
    'file tempo sets the metronome bpm and a normal song keeps it',
    () async {
      metro.tempo(90);
      await transport.attach(entry(fileTempo: true), sections);
      expect(container.read(metronomeProvider).bpm, 120);
      expect(engine.loads.last.renderBpm, 120);
      metro.tempo(90);
      await transport.attach(entry(), sections);
      expect(container.read(metronomeProvider).bpm, 90);
      expect(engine.loads.last.renderBpm, 90);
    },
  );

  test('bar stop waits for engine stopped event', () async {
    await transport.attach(entry(), sections);
    await transport.launch('verse');
    engine.playing(engine.commands.last);
    engine.barEvents.add(4);
    await transport.stop(atBar: true);
    final stop = engine.commands.last;
    expect(stop.kind, BackingKind.stop);
    expect(stop.atBar, 5);
    expect(container.read(backingTransportProvider).playingId, 'verse');
    engine.events.add(BackingState(stop.token, BackingStateKind.stopped, 5));
    expect(container.read(backingTransportProvider).playingId, isNull);
    expect(container.read(backingTransportProvider).queuedId, isNull);
  });

  test('metronome stop clears pad state and permits another launch', () async {
    await transport.attach(entry(), sections);
    await transport.launch('verse');
    engine.playing(engine.commands.last);
    metro.stop();
    expect(container.read(backingTransportProvider).playingId, isNull);
    expect(container.read(backingTransportProvider).queuedId, isNull);
    expect(engine.commands.last.kind, BackingKind.stop);
    await transport.launch('chorus');
    expect(engine.commands.last.kind, BackingKind.launch);
    expect(engine.commands.last.atBar, 2);
    expect(engine.loads, hasLength(1));
  });

  test('tempo reload preserves stem gains', () async {
    await transport.attach(entry(), sections);
    transport.minusOne('Bass');
    metro.tempo(160);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(engine.gains[engine.loads.last.names.indexOf('Bass')], 0);
    expect(engine.loads, hasLength(2));
  });

  test('stop during tempo rendering cancels automatic resume', () async {
    await transport.attach(entry(), sections);
    await transport.launch('verse');
    engine.playing(engine.commands.last);
    metro.tempo(150);
    await transport.stop();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(engine.loads, hasLength(2));
    expect(engine.commands, hasLength(1));
    expect(container.read(backingTransportProvider).playingId, isNull);
  });
}
