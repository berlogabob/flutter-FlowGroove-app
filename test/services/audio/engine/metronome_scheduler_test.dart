import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/render_config.dart';
import 'package:flowgroove/services/audio/engine/pcm_click_renderer.dart';
import 'package:flowgroove/services/audio/engine/metronome_scheduler.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';
import '../../../helpers/fake_audio_sink.dart';

RenderConfig cfg({int subdivisions = 2}) => RenderConfig(
      bpm: 120,
      beats: 4,
      subdivisions: subdivisions,
      beatModes: const [],
      accentEnabled: true,
      accentFrequency: 1600,
      beatFrequency: 800,
      accentBeatFrequency: 2000,
      volume: 1.0,
      countInBars: 0,
      latencyOffsetFrames: 0,
    );

const int kSampleRate = 48000;
const int kChunkFrames = 9600; // 200ms
const int kLookaheadFrames = 3 * kChunkFrames; // 600ms

void main() {
  /// Scheduler with a manual clock. Driving the clock (rather than fakeAsync
  /// around the real Timer, which deadlocks the runner) is the deterministic
  /// seam for the wall-clock feeder.
  ({MetronomeScheduler s, FakeAudioSink sink, void Function(int) advanceMs})
      build() {
    final sink = FakeAudioSink();
    var nowUs = 0;
    final s = MetronomeScheduler(
      sink: sink,
      renderer: PcmClickRenderer(sampleRate: kSampleRate),
      testMode: true,
      clockMicros: () => nowUs,
    );
    return (s: s, sink: sink, advanceMs: (ms) => nowUs += ms * 1000);
  }

  test('start opens the sink and primes exactly the lookahead depth', () async {
    final t = build();
    await t.s.start(cfg());
    expect(t.sink.openCount, 1);
    expect(t.sink.pushed.length, 3);
    expect(t.s.currentFrame, kLookaheadFrames);
    expect(t.s.starvationEvents, 0);
  });

  test('steady state pushes exactly one chunk per period', () async {
    final t = build();
    await t.s.start(cfg());
    for (var i = 1; i <= 5; i++) {
      final before = t.sink.pushed.length;
      t.advanceMs(200);
      t.s.pumpForTest();
      expect(t.sink.pushed.length - before, 1, reason: 'period $i');
      expect(t.s.currentFrame, i * kChunkFrames + kLookaheadFrames);
    }
    expect(t.s.starvationEvents, 0);
  });

  test('feeder catches up after a sub-lookahead stall', () async {
    // FAILS before the fix: the old feeder pushed exactly one chunk per
    // callback, so a 500ms gap permanently lost 300ms of audio.
    final t = build();
    await t.s.start(cfg());
    final before = t.sink.pushed.length;

    t.advanceMs(500);
    t.s.pumpForTest();

    final pushed = t.sink.pushed.length - before;
    expect(pushed, greaterThan(1), reason: 'must catch up, not push one chunk');
    // The 600ms buffer covered the 500ms gap, so no audio was actually lost.
    expect(t.s.starvationEvents, 0);
    expect(t.s.droppedFrames, 0);
    // Cursor is back to a full lookahead beyond now.
    const elapsed = 500 * kSampleRate ~/ 1000;
    expect(t.s.currentFrame, greaterThanOrEqualTo(elapsed + kLookaheadFrames));
  });

  test('feeder resyncs to wall clock after a long stall', () async {
    // The 118s-hole case. FAILS before the fix (which would have needed ~590
    // chunks to catch up and never even tried).
    final t = build();
    await t.s.start(cfg());
    final before = t.sink.pushed.length;

    t.advanceMs(120000);
    t.s.pumpForTest();

    const elapsed = 120 * kSampleRate;
    expect(t.s.starvationEvents, 1);
    // Exactly the silence the device emitted: everything past the buffer.
    expect(t.s.droppedFrames, elapsed - kLookaheadFrames);
    expect(t.sink.pushed.length - before, 3, reason: '3 chunks, not 590');
    expect(t.s.currentFrame, elapsed + kLookaheadFrames);
  });

  test('catch-up never exceeds the per-pump cap', () async {
    final t = build();
    await t.s.start(cfg());
    final before = t.sink.pushed.length;
    t.advanceMs(120000);
    t.s.pumpForTest();
    expect(t.sink.pushed.length - before, lessThanOrEqualTo(6));
    expect(t.s.cappedPumps, 0, reason: 'resync should bound work without the cap');
  });

  test('resync keeps clicks on the beat grid', () async {
    // Phase safety: tick positions come from the ABSOLUTE frame index, so a
    // resync must skip past ticks without shifting the grid.
    final t = build();
    await t.s.start(cfg(subdivisions: 1));
    const tickFrames = 24000; // 120bpm, 1 subdivision @48k

    // Land deliberately OFF the grid (120.007s).
    t.advanceMs(120007);
    t.sink.pushed.clear();
    t.s.pumpForTest();

    final resyncFrame = 120007 * kSampleRate ~/ 1000;
    expect(t.s.starvationEvents, 1);

    // Concatenate what was rendered from the resync point and find the click.
    final joined = <double>[];
    for (final b in t.sink.pushed) {
      joined.addAll(b);
    }
    // Skip the leading region: the resync landed mid-click, so the buffer
    // opens with that click's decaying tail. We care about the NEXT click.
    const tailGuard = 3000;
    var peakIdx = tailGuard;
    var peak = 0.0;
    for (var i = tailGuard; i < joined.length; i++) {
      final v = joined[i].abs();
      if (v > peak) {
        peak = v;
        peakIdx = i;
      }
    }
    expect(peak, greaterThan(0.1), reason: 'a click should have rendered');

    final absolute = resyncFrame + peakIdx;
    final offGrid = absolute % tickFrames;
    final distance = offGrid < tickFrames ~/ 2 ? offGrid : tickFrames - offGrid;
    expect(distance, lessThan(64),
        reason: 'click at absolute frame $absolute is off the $tickFrames grid');
    // And it is the FIRST tick at or after the resync point.
    final expectedTick = ((resyncFrame + tickFrames - 1) ~/ tickFrames) * tickFrames;
    expect((absolute - expectedTick).abs(), lessThan(64));
  });

  test('recover success does not re-enter recovery', () async {
    // Reproduces RC2 at the scheduler: a sink whose recover() success emits an
    // event. Before the fix (sink emitting deviceChanged + no guard) this
    // recursed forever, tearing the audio device down each cycle.
    final t = build();
    await t.s.start(cfg());
    t.sink.recoverEmits = const SinkEvent(SinkEventType.deviceChanged);

    t.sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await pumpEventQueue(times: 20);

    expect(t.sink.recoverCount, 1);
  });

  test('recovered event re-primes without recovering again', () async {
    // The production shape after the fix: soloud_sink emits `recovered`.
    final t = build();
    await t.s.start(cfg());
    t.sink.recoverEmits = const SinkEvent(SinkEventType.recovered);
    final before = t.sink.pushed.length;

    t.advanceMs(400); // buffer drained while recovering
    t.sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await pumpEventQueue(times: 20);

    expect(t.sink.recoverCount, 1);
    expect(t.sink.lastRecoverFrame, isNotNull);
    expect(t.sink.pushed.length, greaterThan(before),
        reason: 'recovered should top the buffer back up');
  });

  test('recovery is budgeted, and a successful recovery restores the budget',
      () async {
    final t = build();
    await t.s.start(cfg());

    // A sink that never reports success burns the budget and then stops.
    for (var i = 0; i < 5; i++) {
      t.sink.emit(const SinkEvent(SinkEventType.error));
      await pumpEventQueue(times: 10);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    expect(t.sink.recoverCount, 3, reason: 'capped at _maxRecoverAttempts');
    expect(t.s.recoverGiveUps, greaterThan(0));

    // Proof of health restores it, so a gigging user who keeps replugging
    // headphones keeps getting recoveries.
    t.sink.emit(const SinkEvent(SinkEventType.recovered));
    await pumpEventQueue(times: 10);
    t.sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await pumpEventQueue(times: 10);
    expect(t.sink.recoverCount, 4);
  });

  test('nothing is pumped while recovering', () async {
    final t = build();
    await t.s.start(cfg());
    final gate = Completer<void>();
    t.sink.recoverGate = gate;

    t.sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await pumpEventQueue(times: 5);
    final during = t.sink.pushed.length;

    t.advanceMs(1000);
    t.s.pumpForTest();
    expect(t.sink.pushed.length, during, reason: 'feeder must stay quiet');

    gate.complete();
    await pumpEventQueue(times: 5);
  });

  test('a throwing framesQueued never breaks pumping', () async {
    final t = build();
    await t.s.start(cfg());
    t.sink.framesQueuedThrows = true;
    final before = t.sink.pushed.length;

    t.advanceMs(200);
    expect(t.s.pumpForTest, returnsNormally);
    expect(t.sink.pushed.length, greaterThan(before));
  });

  test('recover is asked to resume at the current frame', () async {
    final t = build();
    await t.s.start(cfg());
    t.sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await pumpEventQueue(times: 10);
    expect(t.sink.recoverCount, 1);
    expect(t.sink.lastRecoverFrame, kLookaheadFrames);
  });
}
