import 'dart:typed_data';

import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flowgroove/services/audio/backing_engine_factory.dart';
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

  test('a cancel removes the pending launch before it plays', () async {
    final states = <BackingState>[];
    final subscription = engine.states.listen(states.add);
    addTearDown(subscription.cancel);

    await engine.command(
      BackingCommand(
        token: 1,
        kind: BackingKind.launch,
        fromBar: 0,
        bars: 4,
        loop: false,
        atBar: 4,
      ),
    );
    await engine.command(
      BackingCommand(
        token: 2,
        kind: BackingKind.launch,
        fromBar: 4,
        bars: 4,
        loop: false,
        atBar: 8,
      ),
    );
    await engine.command(
      const BackingCommand(
        token: 3,
        kind: BackingKind.cancel,
        fromBar: 2,
        atBar: 0,
      ),
    );

    // Advance the clock past bar 8 and pump.
    clock.currentTime = clock.barTimeSeconds(9);
    engine.pump();
    await Future<void>.delayed(Duration.zero);

    final playedForToken2 = states
        .where((s) => s.token == 2 && s.kind == BackingStateKind.playing)
        .toList();
    final playedToken1 = states
        .where((s) => s.token == 1 && s.kind == BackingStateKind.playing)
        .toList();
    expect(playedForToken2, isEmpty);
    expect(playedToken1, isNotEmpty);
  });
}
