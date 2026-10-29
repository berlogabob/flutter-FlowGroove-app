import 'dart:typed_data';

import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flowgroove/services/audio/backing_engine_factory.dart';
import 'package:flowgroove/services/audio/backing_engine_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClock implements BackingClock {
  @override
  double currentTime = 10;

  @override
  double bpm = 120;

  double epoch = 10;
  double barSeconds = 2;

  @override
  double barTimeSeconds(int bar) => epoch + bar * barSeconds;
}

class FakeSource implements BackingSource {
  FakeSource(this.stem, this.time, this.offset, this.duration);

  final int stem;
  final double time;
  final double offset;
  final double duration;
  double? stoppedAt;

  @override
  void stop(double atTime) => stoppedAt = atTime;
}

class FakeSources implements BackingSourceFactory {
  final started = <FakeSource>[];
  final gains = <int, double>{};

  @override
  int get sampleRate => 1000;

  @override
  void load(BackingStems stems) {}

  @override
  BackingSource start(int stem, double atTime, double offset, double duration) {
    final source = FakeSource(stem, atTime, offset, duration);
    started.add(source);
    return source;
  }

  @override
  void setGain(int stem, double gain) => gains[stem] = gain;

  @override
  void clear() => gains.clear();
}

BackingStems stems({double bpm = 120}) => BackingStems(
  stems: [Int16List(80000), Int16List(80000)],
  names: const ['Bass', 'Drums'],
  sampleRate: 1000,
  renderBpm: bpm,
  ticksPerBar: 4,
  intervalMicros: 500000,
);

BackingCommand launch({
  int atBar = 0,
  int fromBar = 0,
  int bars = 2,
  bool loop = true,
  int token = 1,
}) => BackingCommand(
  token: token,
  kind: BackingKind.launch,
  fromBar: fromBar,
  bars: bars,
  loop: loop,
  atBar: atBar,
);

void main() {
  late FakeClock clock;
  late FakeSources sources;
  late WebBackingScheduler engine;

  setUp(() async {
    clock = FakeClock();
    sources = FakeSources();
    engine = WebBackingScheduler(
      clock: clock,
      sources: sources,
      automaticPump: false,
    );
    await engine.load(stems());
  });

  tearDown(() => engine.dispose());

  test('launch at bar 3 uses the click grid and song sample offset', () async {
    clock.currentTime = clock.barTimeSeconds(2);
    await engine.command(launch(atBar: 3, fromBar: 5));

    expect(sources.started, hasLength(2));
    for (final source in sources.started) {
      expect(source.time, clock.barTimeSeconds(3));
      expect(source.offset, 10);
      expect(source.duration, 2);
    }
    expect(sources.started.map((source) => source.stem), [0, 1]);
  });

  test('two-bar loop wraps song bars while transport continues', () async {
    await engine.command(launch(fromBar: 4));
    for (var bar = 1; bar <= 4; bar++) {
      clock.currentTime = clock.barTimeSeconds(bar);
      engine.pump();
    }

    final firstStem = sources.started.where((source) => source.stem == 0);
    expect(firstStem.map((source) => source.offset), [8, 10, 8, 10, 8, 10]);
    expect(
      firstStem.map((source) => source.time),
      List.generate(6, clock.barTimeSeconds),
    );
  });

  test('stop cancels future sources and preserves the current bar', () async {
    await engine.command(launch());
    await engine.command(
      const BackingCommand(token: 2, kind: BackingKind.stop, atBar: 1),
    );

    expect(
      sources.started
          .where((source) => source.time == clock.barTimeSeconds(0))
          .every((source) => source.stoppedAt == null),
      isTrue,
    );
    expect(
      sources.started
          .where((source) => source.time >= clock.barTimeSeconds(1))
          .every((source) => source.stoppedAt == clock.currentTime),
      isTrue,
    );
    clock.currentTime = clock.barTimeSeconds(4);
    engine.pump();
    expect(sources.started, hasLength(4));
  });

  test(
    'BPM mismatch schedules nothing and cancels already scheduled audio',
    () async {
      clock.bpm = 121;
      await engine.command(launch());
      expect(sources.started, isEmpty);

      clock.bpm = 120;
      engine.pump();
      expect(sources.started, hasLength(4));
      clock.bpm = 121;
      engine.pump();
      expect(
        sources.started.every((source) => source.stoppedAt != null),
        isTrue,
      );
      clock.currentTime = clock.barTimeSeconds(10);
      engine.pump();
      expect(sources.started, hasLength(4));
    },
  );

  test(
    '40 bars never schedule beyond lookahead or duplicate sources',
    () async {
      await engine.command(launch(bars: 40, loop: false));
      for (var bar = 0; bar < 40; bar++) {
        clock.currentTime = clock.barTimeSeconds(bar);
        engine.pump();
        final live = sources.started.where(
          (source) =>
              source.stoppedAt == null && source.time >= clock.currentTime,
        );
        expect(live.length, lessThanOrEqualTo(4));
        expect(
          live.every((source) => source.time < clock.currentTime + 4),
          isTrue,
        );
      }
      expect(sources.started, hasLength(80));
      expect(
        sources.started.map((source) => (source.stem, source.time)).toSet(),
        hasLength(80),
      );
    },
  );

  test(
    'states follow audible boundaries, including non-loop completion',
    () async {
      final states = <BackingState>[];
      final bars = <int>[];
      final stateSubscription = engine.states.listen(states.add);
      final barSubscription = engine.bars.listen(bars.add);
      addTearDown(stateSubscription.cancel);
      addTearDown(barSubscription.cancel);

      await engine.command(launch(atBar: 1, loop: false));
      await Future<void>.delayed(Duration.zero);
      expect(states.map((state) => state.kind), [BackingStateKind.queued]);
      clock.currentTime = clock.barTimeSeconds(1);
      engine.pump();
      await Future<void>.delayed(Duration.zero);
      expect(states.last.kind, BackingStateKind.playing);
      expect(states.last.bar, 1);
      clock.currentTime = clock.barTimeSeconds(3);
      engine.pump();
      await Future<void>.delayed(Duration.zero);
      expect(states.last.kind, BackingStateKind.stopped);
      expect(states.last.bar, 3);
      expect(bars, [0, 1, 3]);
      expect(sources.started, hasLength(4));
    },
  );

  test('replacement launch replaces already scheduled bars', () async {
    await engine.command(launch());
    await engine.command(launch(atBar: 1, fromBar: 8, token: 2));
    final atOne = sources.started.where(
      (source) => source.time == clock.barTimeSeconds(1),
    );
    expect(atOne.where((source) => source.stoppedAt != null), hasLength(2));
    expect(
      atOne
          .where((source) => source.stoppedAt == null)
          .map((source) => source.offset),
      [16, 16],
    );
  });

  test(
    'fractional bars use absolute samples and retain exact boundaries',
    () async {
      clock
        ..epoch = 12.5
        ..barSeconds = 12 * 165289 / 1e6
        ..bpm = 121;
      await engine.load(
        BackingStems(
          stems: [Int16List(40000)],
          names: const ['Bass'],
          sampleRate: 1000,
          renderBpm: 121,
          ticksPerBar: 12,
          intervalMicros: 165289,
        ),
      );
      clock.currentTime = clock.barTimeSeconds(3);
      await engine.command(launch(atBar: 3, fromBar: 7, bars: 40));
      expect(sources.started.first.time, clock.barTimeSeconds(3));
      expect(
        sources.started.first.offset,
        (7 * 12 * 165289 / 1000).round() / 1000,
      );
      for (var bar = 4; bar < 40; bar++) {
        clock.currentTime = clock.barTimeSeconds(bar);
        engine.pump();
        expect(
          sources.started.where(
            (source) => source.time == clock.barTimeSeconds(bar),
          ),
          hasLength(1),
        );
      }
    },
  );

  test(
    'throttled pump skips missed bars and keeps the loop position',
    () async {
      await engine.command(launch());
      clock.currentTime = clock.barTimeSeconds(9) + 0.5;
      engine.pump();
      final resumed = sources.started.skip(4).toList();
      expect(resumed.first.time, clock.barTimeSeconds(10));
      expect(resumed.first.offset, 0);
      expect(
        resumed.every((source) => source.time >= clock.currentTime),
        isTrue,
      );
    },
  );

  test('gain forwards per stem and clear cancels sources', () async {
    await engine.command(launch());
    engine.setGain(1, 0.25);
    expect(sources.gains, {1: 0.25});
    expect(() => engine.setGain(2, 1), throwsArgumentError);
    expect(() => engine.setGain(0, double.nan), throwsArgumentError);
    await engine.clear();
    expect(sources.started.every((source) => source.stoppedAt != null), isTrue);
    clock.currentTime = clock.barTimeSeconds(2);
    engine.pump();
    expect(sources.started, hasLength(4));
  });

  test('factory selects Android only; other platforms use the no-op', () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(createBackingEngine(), isA<PlatformBackingEngine>());
    for (final platform in TargetPlatform.values.where(
      (platform) => platform != TargetPlatform.android,
    )) {
      debugDefaultTargetPlatformOverride = platform;
      final stub = createBackingEngine();
      expect(stub, isA<StubBackingEngine>());
      expect(await stub.states.toList(), isEmpty);
      expect(await stub.bars.toList(), isEmpty);
      await expectLater(stub.load(stems()), throwsUnsupportedError);
      await stub.command(launch());
      stub.setGain(0, 0.5);
      await stub.clear();
      await stub.dispose();
    }
  });
}
