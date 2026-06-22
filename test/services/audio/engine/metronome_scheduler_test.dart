import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/render_config.dart';
import 'package:flowgroove/services/audio/engine/pcm_click_renderer.dart';
import 'package:flowgroove/services/audio/engine/metronome_scheduler.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';
import '../../../helpers/fake_audio_sink.dart';

RenderConfig cfg() => const RenderConfig(
      bpm: 120, beats: 4, subdivisions: 2, beatModes: [],
      accentEnabled: true, accentFrequency: 1600, beatFrequency: 800,
      accentBeatFrequency: 2000,
      volume: 1.0, countInBars: 0, latencyOffsetFrames: 0);

void main() {
  test('start opens sink and pumping advances the absolute frame', () async {
    final sink = FakeAudioSink();
    final s = MetronomeScheduler(sink: sink, renderer: PcmClickRenderer(sampleRate: 48000), testMode: true);
    await s.start(cfg());
    expect(sink.openCount, 1);
    s.pumpForTest(); // renders one 200ms chunk = 9600 frames
    s.pumpForTest();
    expect(s.currentFrame, 19200);
    expect(sink.pushed.length, 2);
  });

  test('deviceChanged triggers recover at current frame and resumes without losing frames', () async {
    final sink = FakeAudioSink();
    final s = MetronomeScheduler(sink: sink, renderer: PcmClickRenderer(sampleRate: 48000), testMode: true);
    await s.start(cfg());
    s.pumpForTest(); // frame -> 9600
    sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await Future<void>.delayed(Duration.zero);
    expect(sink.recoverCount, 1);
    expect(sink.lastRecoverFrame, 9600);
    s.pumpForTest();
    expect(s.currentFrame, 19200); // continues from 9600, nothing lost
  });
}
