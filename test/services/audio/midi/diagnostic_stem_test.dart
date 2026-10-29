import 'package:flowgroove/services/audio/midi/diagnostic_stem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final sampleRate in [44100, 48000]) {
    for (final subdivisions in [1, 2, 3, 4]) {
      test(
        'exact length and one burst per beat at $sampleRate/$subdivisions',
        () {
          const bpm = 123.0;
          const bars = 4;
          const beatsPerBar = 4;
          final interval = (60000000 / bpm / subdivisions).round();
          final stems = diagnosticStems(
            sampleRate: sampleRate,
            intervalMicros: interval,
            ticksPerBar: beatsPerBar * subdivisions,
            renderBpm: bpm,
            bars: bars,
          );
          final pcm = stems.stems.single;
          final tickFrames = interval * sampleRate / 1000000;
          final burstFrames = (sampleRate * 0.020).round();
          expect(stems.names, hasLength(1));
          expect(
            pcm.length,
            (bars * beatsPerBar * subdivisions * tickFrames).round(),
          );
          var end = 0;
          for (var beat = 0; beat < bars * beatsPerBar; beat++) {
            final start = (beat * subdivisions * tickFrames).round();
            expect(pcm.sublist(end, start), everyElement(0));
            final burst = pcm.sublist(start, start + burstFrames);
            expect(burst, contains(isNot(0)));
            for (var i = 0; i < burstFrames; i += sampleRate ~/ 1000) {
              expect(
                burst.skip(i).take(sampleRate ~/ 1000),
                contains(predicate<int>((sample) => sample.abs() > 8000)),
              );
            }
            end = start + burstFrames;
          }
          expect(pcm.sublist(end), everyElement(0));
        },
      );
    }
  }
}
