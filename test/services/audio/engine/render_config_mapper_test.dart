import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowgroove/models/beat_mode.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart';
import 'package:flowgroove/services/audio/engine/latency_calibration.dart';
import 'package:flowgroove/services/audio/engine/render_config_mapper.dart';

MetronomePlaybackConfig _config({
  int bpm = 120,
  int accentBeats = 4,
  int regularBeats = 2,
  bool accentEnabled = true,
  double accentFrequency = 1000,
  double beatFrequency = 800,
  double volume = 0.8,
  int countInBars = 1,
  List<List<BeatMode>>? beatModes,
}) {
  return MetronomePlaybackConfig(
    bpm: bpm,
    accentBeats: accentBeats,
    regularBeats: regularBeats,
    beatModes: beatModes ??
        List<List<BeatMode>>.generate(
          accentBeats,
          (_) => List<BeatMode>.filled(regularBeats, BeatMode.normal),
        ),
    waveType: 'sine',
    volume: volume,
    accentEnabled: accentEnabled,
    accentFrequency: accentFrequency,
    beatFrequency: beatFrequency,
    hapticsEnabled: false,
    countInBars: countInBars,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('maps playback config fields one-to-one', () async {
    final cal = LatencyCalibration(prefs: await SharedPreferences.getInstance());
    final cfg = renderConfigFromPlayback(
      _config(),
      route: AudioRoute.speaker,
      cal: cal,
      sampleRate: 48000,
    );

    expect(cfg.bpm, 120);
    expect(cfg.beats, 4); // accentBeats -> beats
    expect(cfg.subdivisions, 2); // regularBeats -> subdivisions
    expect(cfg.accentEnabled, isTrue);
    expect(cfg.accentFrequency, 1000);
    expect(cfg.beatFrequency, 800);
    expect(cfg.volume, 0.8);
    expect(cfg.countInBars, 1);
    expect(cfg.beatModes.length, 4);
    expect(cfg.beatModes.first.length, 2);
  });

  test('speaker route has zero latency frames by default', () async {
    final cal = LatencyCalibration(prefs: await SharedPreferences.getInstance());
    final cfg = renderConfigFromPlayback(
      _config(),
      route: AudioRoute.speaker,
      cal: cal,
      sampleRate: 48000,
    );
    expect(cfg.latencyOffsetFrames, 0);
  });

  test('bluetooth route applies 150ms default latency @48k', () async {
    final cal = LatencyCalibration(prefs: await SharedPreferences.getInstance());
    final cfg = renderConfigFromPlayback(
      _config(),
      route: AudioRoute.bluetooth,
      cal: cal,
      sampleRate: 48000,
    );
    // 150ms @ 48000 = 0.150 * 48000 = 7200 frames.
    expect(cfg.latencyOffsetFrames, 7200);
  });

  test('user offset stacks on route default', () async {
    final cal = LatencyCalibration(prefs: await SharedPreferences.getInstance())
      ..setUserOffsetMs(10); // +10ms
    final cfg = renderConfigFromPlayback(
      _config(),
      route: AudioRoute.wired, // 20ms default
      cal: cal,
      sampleRate: 48000,
    );
    // (20 + 10)ms @ 48000 = 0.030 * 48000 = 1440 frames.
    expect(cfg.latencyOffsetFrames, 1440);
  });
}
