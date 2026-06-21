import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/services/audio/engine/render_config.dart';
import 'package:flowgroove/services/audio/engine/pcm_click_renderer.dart';

RenderConfig cfg({int bpm = 120, int beats = 4, int sub = 1, int latency = 0}) => RenderConfig(
      bpm: bpm, beats: beats, subdivisions: sub, beatModes: const [],
      accentEnabled: true, accentFrequency: 1600, beatFrequency: 800,
      volume: 1.0, countInBars: 0, latencyOffsetFrames: latency,
    );

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
    expect((firstOnset(pcm, 0)).abs() <= 6, isTrue);
    expect((firstOnset(pcm, 11990) - 12000).abs() <= 6, isTrue);
    expect((firstOnset(pcm, 23990) - 24000).abs() <= 6, isTrue);
    expect((firstOnset(pcm, 35990) - 36000).abs() <= 6, isTrue);
  });

  test('latency offset shifts every click earlier by exactly latencyOffsetFrames', () {
    final r = PcmClickRenderer(sampleRate: sr);
    final c = cfg(bpm: 120, sub: 1, latency: 480); // 10ms @48k
    final pcm = r.renderChunk(config: c, startFrame: 0, frameCount: 48000).toList();
    // tick 1 at 24000, shifted to 23520
    expect((firstOnset(pcm, 23500) - 23520).abs() <= 6, isTrue);
  });
}
