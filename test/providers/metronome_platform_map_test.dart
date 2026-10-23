import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/providers/metronome_runtime_providers.dart';

void main() {
  group('MetronomePlaybackConfig.toPlatformMap', () {
    test('encodes the core playback parameters', () {
      final config = MetronomePlaybackConfig(
        bpm: 97,
        accentBeats: 4,
        regularBeats: 2,
        beatModes: [],
        waveType: 'sine',
        volume: 0.5,
        accentEnabled: true,
        accentFrequency: 1000,
        beatFrequency: 800,
        accentBeatFrequency: 1200,
        hapticsEnabled: false,
      );
      final map = config.toPlatformMap(initialTick: 0);

      expect(map['bpm'], 97.0);
      expect(map['ticksPerBar'], 8);
      expect(map['intervalMicros'], config.interval.inMicroseconds);
      expect(map['initialTick'], 0);
    });
  });
}
