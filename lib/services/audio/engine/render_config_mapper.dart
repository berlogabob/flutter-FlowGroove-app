import '../../../providers/metronome_runtime_providers.dart'
    show MetronomePlaybackConfig;
import 'latency_calibration.dart';
import 'render_config.dart';

/// Maps a [MetronomePlaybackConfig] (the playback-layer config the existing
/// [MetronomePlaybackClient] interface receives) into a sample-accurate
/// [RenderConfig] consumed by [PcmClickRenderer].
///
/// `accentBeats` -> `beats` (beats per bar) and `regularBeats` -> `subdivisions`
/// (per beat). The route-dependent latency is resolved through [cal] so the
/// renderer can pre-roll clicks ahead of audible output (e.g. Bluetooth adds a
/// ~150ms default offset).
RenderConfig renderConfigFromPlayback(
  MetronomePlaybackConfig c, {
  required AudioRoute route,
  required LatencyCalibration cal,
  required int sampleRate,
}) {
  return RenderConfig(
    bpm: c.bpm,
    beats: c.accentBeats,
    subdivisions: c.regularBeats,
    beatModes: c.beatModes,
    accentEnabled: c.accentEnabled,
    accentFrequency: c.accentFrequency,
    beatFrequency: c.beatFrequency,
    accentBeatFrequency: c.accentBeatFrequency,
    volume: c.volume,
    countInBars: c.countInBars,
    latencyOffsetFrames: cal.effectiveOffsetFrames(route, sampleRate),
    waveType: c.waveType,
  );
}
