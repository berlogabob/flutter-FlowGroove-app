import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart';
import 'package:flowgroove/models/beat_mode.dart';

class SilentAudioClient implements MetronomeAudioClient {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> preWarmPlayers() async {}

  @override
  Future<void> playClick({
    required bool isAccent,
    required String waveType,
    required double volume,
    double? accentFrequency,
    double? beatFrequency,
  }) async {}

  @override
  Future<void> playTest() async {}

  @override
  Future<void> dispose() async {}
}

class FakeHapticsClient implements MetronomeHapticsClient {
  @override
  void heavyClick() {}
  @override
  void mediumClick() {}
  @override
  void tick() {}
  @override
  void lightImpact() {}
}

void main() {
  group('FlutterMetronomePlaybackClient', () {
    late SilentAudioClient audioClient;
    late FakeHapticsClient hapticsClient;
    late FlutterMetronomePlaybackClient client;

    setUp(() {
      audioClient = SilentAudioClient();
      hapticsClient = FakeHapticsClient();
      client = FlutterMetronomePlaybackClient(
        audioClient: audioClient,
        hapticsClient: hapticsClient,
      );
    });

    tearDown(() {
      client.dispose();
    });

    /// Creates a config with a very short interval for fast test execution.
    /// 600 BPM with 1 regular beat = 100ms intervals.
    MetronomePlaybackConfig _fastConfig() {
      return MetronomePlaybackConfig(
        bpm: 600,
        accentBeats: 4,
        regularBeats: 1,
        beatModes: [
          [BeatMode.accent],
          [BeatMode.normal],
          [BeatMode.normal],
          [BeatMode.normal],
        ],
        waveType: 'sine',
        volume: 0.5,
        accentEnabled: true,
        accentFrequency: 1600.0,
        beatFrequency: 800.0,
        hapticsEnabled: false,
      );
    }

    test(
      'continues ticking when onTick callback throws',
      () async {
        final tickIndices = <int>[];
        var throwCount = 0;
        final config = _fastConfig();

        await client.start(
          config,
          onTick: (tick) {
            // Throw on the first few ticks to simulate a transient error
            if (throwCount < 3) {
              throwCount++;
              throw StateError('simulated tick processing error');
            }
            tickIndices.add(tick.index);
          },
        );

        // Wait for ticks to fire (600 BPM = 100ms interval)
        // First ~3 will throw, then should recover
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(
          throwCount,
          greaterThanOrEqualTo(3),
          reason: 'Should have thrown on first ticks',
        );
        expect(
          tickIndices.length,
          greaterThan(0),
          reason: 'Metronome should continue ticking after onTick throws',
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'dispose stops the scheduler and cleans up',
      () async {
        final tickIndices = <int>[];
        final config = _fastConfig();

        await client.start(
          config,
          onTick: (tick) => tickIndices.add(tick.index),
        );

        await Future<void>.delayed(const Duration(milliseconds: 350));
        expect(tickIndices.length, greaterThan(0));

        client.dispose();

        final countBeforeDispose = tickIndices.length;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(
          tickIndices.length,
          countBeforeDispose,
          reason: 'No more ticks should fire after dispose',
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}
