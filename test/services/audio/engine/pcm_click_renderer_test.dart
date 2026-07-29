import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/services/audio/engine/render_config.dart';
import 'package:flowgroove/services/audio/engine/pcm_click_renderer.dart';

RenderConfig cfg({
  int bpm = 120,
  int beats = 4,
  int sub = 1,
  int latency = 0,
  String wave = 'sine',
  double accentFrequency = 1600,
  double beatFrequency = 800,
  double accentBeatFrequency = 2000,
  List<List<BeatMode>> beatModes = const [],
}) =>
    RenderConfig(
      bpm: bpm, beats: beats, subdivisions: sub, beatModes: beatModes,
      accentEnabled: true, accentFrequency: accentFrequency,
      beatFrequency: beatFrequency, accentBeatFrequency: accentBeatFrequency,
      volume: 1.0, countInBars: 0, latencyOffsetFrames: latency, waveType: wave,
    );

// fraction of a click's samples driven to near full scale (|v| > 0.9)
double fullScaleFraction(List<double> pcm) {
  var loud = 0, total = 0;
  for (final v in pcm) {
    if (v.abs() > 0.001) {
      total++;
      if (v.abs() > 0.9) loud++;
    }
  }
  return total == 0 ? 0 : loud / total;
}

// index of first frame whose |sample| exceeds a small threshold at/after `from`
int firstOnset(List<double> pcm, int from) {
  for (var i = from; i < pcm.length; i++) {
    if (pcm[i].abs() > 0.05) return i;
  }
  return -1;
}

void main() {
  const sr = 48000;
  test('frameForTick spaces ticks by exact sample interval', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 1); // 0.5s per tick => 24000 frames
    expect(r.frameForTick(c, 0), 0);
    expect(r.frameForTick(c, 1), 24000);
    expect(r.frameForTick(c, 2), 48000);
  });

  test('subdivision 2 places a click at the exact half-beat frame, zero drift', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 2); // 0.25s per tick => 12000 frames
    final pcm = r.renderChunk(config: c, startFrame: 0, frameCount: 48000).toList();
    // clicks expected at frames 0, 12000, 24000, 36000 (+/- a couple frames of attack)
    expect((firstOnset(pcm, 0)).abs() <= 5, isTrue);
    expect((firstOnset(pcm, 11990) - 12000).abs() <= 5, isTrue);
    expect((firstOnset(pcm, 23990) - 24000).abs() <= 5, isTrue);
    expect((firstOnset(pcm, 35990) - 36000).abs() <= 5, isTrue);
  });

  test('latency offset shifts every click earlier by exactly latencyOffsetFrames', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 1, latency: 480); // 10ms @48k
    final pcm = r.renderChunk(config: c, startFrame: 0, frameCount: 48000).toList();
    // tick 1 at 24000, shifted to 23520
    expect((firstOnset(pcm, 23500) - 23520).abs() <= 5, isTrue);
  });

  test('no accumulating drift: click at tick 100 lands at the exact frame', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 1); // 24000 frames per tick
    const tick = 100;
    final expected = r.frameForTick(c, tick); // 2,400,000
    // render a window around the far tick
    final pcm = r.renderChunk(config: c, startFrame: expected - 100, frameCount: 200).toList();
    final onset = firstOnset(pcm, 0); // index within the window
    // onset is (expected - (expected-100)) = 100, plus the 4-frame accent attack
    expect((onset - 100).abs() <= 5, isTrue);
  });

  test('waveType changes the rendered waveform', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final sine = r.renderChunk(config: cfg(), startFrame: 0, frameCount: 4000).toList();
    final square = r.renderChunk(config: cfg(wave: 'square'), startFrame: 0, frameCount: 4000).toList();
    final saw = r.renderChunk(config: cfg(wave: 'sawtooth'), startFrame: 0, frameCount: 4000).toList();
    // Different waveforms produce different buffers.
    expect(sine, isNot(equals(square)));
    expect(sine, isNot(equals(saw)));
    // Square is gain-clipped to near full scale far more than sine.
    expect(fullScaleFraction(square) > fullScaleFraction(sine), isTrue);
  });

  test('output gain makes a volume-1.0 click reach near full scale', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final pcm = r.renderChunk(config: cfg(), startFrame: 0, frameCount: 4000).toList();
    final peak = pcm.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    expect(peak > 0.95, isTrue); // gain drives the click to ~full scale, not a quiet sine
  });

  group('three independent pitch tiers', () {
    // 4/4, single subdivision, so tick 0 is the main beat (beat 0, sub 0).
    final accentBeat = <List<BeatMode>>[
      [BeatMode.accent],
      [BeatMode.normal],
      [BeatMode.normal],
      [BeatMode.normal],
    ];
    final normalBeat = <List<BeatMode>>[
      [BeatMode.normal],
      [BeatMode.normal],
      [BeatMode.normal],
      [BeatMode.normal],
    ];

    test('a marked-accent cell renders at the accent pitch, not the primary pitch', () {
      final r = PcmClickRenderer(sampleRate: sr);
      final pcm = r
          .renderChunk(
            config: cfg(
              accentFrequency: 1600,
              beatFrequency: 800,
              accentBeatFrequency: 2400,
              beatModes: accentBeat,
            ),
            startFrame: 0,
            frameCount: 2000,
          )
          .toList();
      final pitch = estimatePitch(pcm, sr);
      // The first click is a main beat marked as accent: it must sound at the
      // accent pitch (2400), clearly nearer 2400 than the primary pitch (1600).
      expect((pitch - 2400).abs() < (pitch - 1600).abs(), isTrue);
    });

    test('a normal main beat ignores the accent pitch entirely', () {
      final r = PcmClickRenderer(sampleRate: sr);
      final a = r
          .renderChunk(
            config: cfg(beatModes: normalBeat, accentBeatFrequency: 2000),
            startFrame: 0,
            frameCount: 2000,
          )
          .toList();
      final b = r
          .renderChunk(
            config: cfg(beatModes: normalBeat, accentBeatFrequency: 700),
            startFrame: 0,
            frameCount: 2000,
          )
          .toList();
      expect(a, equals(b)); // accent pitch is unused for non-accent cells
    });

    test('changing the accent pitch changes a marked-accent cell', () {
      final r = PcmClickRenderer(sampleRate: sr);
      final a = r
          .renderChunk(
            config: cfg(beatModes: accentBeat, accentBeatFrequency: 2000),
            startFrame: 0,
            frameCount: 2000,
          )
          .toList();
      final b = r
          .renderChunk(
            config: cfg(beatModes: accentBeat, accentBeatFrequency: 700),
            startFrame: 0,
            frameCount: 2000,
          )
          .toList();
      expect(a, isNot(equals(b)));
    });
  });
}

/// Rough dominant-pitch estimate via zero crossings across the click body.
/// Good enough to tell the three pitch tiers apart (they are hundreds of Hz
/// apart); not a precise frequency meter.
double estimatePitch(List<double> pcm, int sampleRate) {
  var crossings = 0;
  var first = -1, last = -1;
  var prev = 0.0;
  for (var i = 0; i < pcm.length; i++) {
    final v = pcm[i];
    if (v.abs() > 0.02) {
      if (first < 0) first = i;
      last = i;
    }
    if (prev != 0 && ((prev < 0 && v >= 0) || (prev > 0 && v <= 0))) crossings++;
    prev = v;
  }
  if (first < 0 || last <= first) return 0;
  final seconds = (last - first) / sampleRate;
  return crossings / (2 * seconds);
}
