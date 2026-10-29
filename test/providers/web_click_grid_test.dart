import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart';
import 'package:flowgroove/services/audio/web_audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingAudioEngine extends AudioEngine {
  final times = <double>[];

  @override
  void scheduleClick({
    required double atTime,
    required String waveType,
    required double volume,
    required double frequency,
  }) {
    times.add(atTime);
  }

  @override
  void cancelScheduled() => times.clear();
}

class FakeWebAudioClient extends WebAudioMetronomeAudioClient {
  @override
  final RecordingAudioEngine engine = RecordingAudioEngine();

  @override
  Future<void> initialize() async {}
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

MetronomePlaybackConfig config({
  int bpm = 121,
  int countInBars = 0,
  double volume = 0.5,
  String waveType = 'sine',
}) => MetronomePlaybackConfig(
  bpm: bpm,
  accentBeats: 4,
  regularBeats: 3,
  beatModes: const [
    [BeatMode.accent, BeatMode.normal, BeatMode.normal],
    [BeatMode.normal, BeatMode.normal, BeatMode.normal],
    [BeatMode.normal, BeatMode.normal, BeatMode.normal],
    [BeatMode.normal, BeatMode.normal, BeatMode.normal],
  ],
  waveType: waveType,
  volume: volume,
  accentEnabled: true,
  accentFrequency: 1600,
  beatFrequency: 800,
  accentBeatFrequency: 2000,
  hapticsEnabled: false,
  countInBars: countInBars,
);

void main() {
  late FakeWebAudioClient audio;
  late WebAudioLookaheadPlaybackClient client;
  late double now;

  setUp(() {
    now = 12.5;
    audio = FakeWebAudioClient();
    client = WebAudioLookaheadPlaybackClient(
      webAudioClient: audio,
      hapticsClient: FakeHapticsClient(),
      clock: () => now,
    );
  });

  tearDown(() => client.dispose());

  testWidgets('bar times share the pump grid without accumulated rounding', (
    tester,
  ) async {
    final playbackConfig = config();
    final interval = playbackConfig.interval.inMicroseconds / 1e6;
    await client.start(playbackConfig, onTick: (_) {});

    expect(client.epochSeconds, now + interval);
    expect(client.barTimeSeconds(0), client.epochSeconds);
    expect(client.ticksPerBar, playbackConfig.totalTicks);
    expect(client.tickIntervalSeconds, interval);
    expect(
      client.barTimeSeconds(4),
      client.epochSeconds + 4 * playbackConfig.totalTicks * interval,
    );
    for (var tick = 0; tick < audio.engine.times.length; tick++) {
      expect(audio.engine.times[tick], client.epochSeconds + tick * interval);
    }

    for (final bar in [4, 10000]) {
      now = client.barTimeSeconds(bar);
      audio.engine.times.clear();
      await tester.pump(const Duration(milliseconds: 100));
      expect(audio.engine.times.first, client.barTimeSeconds(bar));
    }
    await client.stop();
  });

  testWidgets('count-in bars occupy transport bars on the same grid', (
    tester,
  ) async {
    await client.start(config(countInBars: 1), onTick: (_) {});

    expect(client.barTimeSeconds(0), client.epochSeconds);
    expect(audio.engine.times.first, client.barTimeSeconds(1));
    await client.stop();
  });

  testWidgets('tempo-neutral updates preserve the grid', (tester) async {
    await client.start(config(), onTick: (_) {});
    final epoch = client.epochSeconds;
    final barFour = client.barTimeSeconds(4);
    final interval = client.tickIntervalSeconds;

    now += 0.75;
    await client.update(config(volume: 0.2, waveType: 'triangle'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(client.epochSeconds, epoch);
    expect(client.tickIntervalSeconds, interval);
    expect(client.barTimeSeconds(4), barFour);
    await client.stop();
  });

  testWidgets('tempo updates retain the next tick and resetPhase reanchors', (
    tester,
  ) async {
    await client.start(config(), onTick: (_) {});
    final nextTick = audio.engine.times.last + client.tickIntervalSeconds;
    final fasterConfig = config(bpm: 180);
    await client.update(fasterConfig);

    now = nextTick - 0.01;
    audio.engine.times.clear();
    await tester.pump(const Duration(milliseconds: 100));
    expect(audio.engine.times.first, closeTo(nextTick, 1e-12));
    expect(
      audio.engine.times[1] - audio.engine.times.first,
      closeTo(fasterConfig.interval.inMicroseconds / 1e6, 1e-12),
    );

    await client.resetPhase(fasterConfig);
    expect(client.epochSeconds, now + client.tickIntervalSeconds);
    expect(client.barTimeSeconds(0), client.epochSeconds);
    await tester.pump(const Duration(milliseconds: 100));
    expect(audio.engine.times.first, client.epochSeconds);
    await client.stop();
  });

  for (final bpm in [60, 600]) {
    testWidgets('lookahead covers two bars or three seconds at $bpm BPM', (
      tester,
    ) async {
      await client.start(config(bpm: bpm), onTick: (_) {});

      expect(client.lookaheadSeconds, greaterThanOrEqualTo(3));
      expect(
        client.lookaheadSeconds,
        greaterThanOrEqualTo(
          2 * client.ticksPerBar * client.tickIntervalSeconds,
        ),
      );
      // The next tick lies at or beyond the horizon: the pump filled it.
      expect(
        audio.engine.times.last + client.tickIntervalSeconds,
        greaterThanOrEqualTo(now + client.lookaheadSeconds),
      );
      await client.stop();
    });
  }
}
