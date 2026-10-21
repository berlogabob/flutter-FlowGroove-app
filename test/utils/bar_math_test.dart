import 'package:flowgroove/utils/bar_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tickIntervalFrames preserves fractional frames', () {
    expect(tickIntervalFrames(487805, 48000), closeTo(23414.64, 1e-9));
  });

  group('barStartFrame', () {
    int startFrame({required int bar, int epochFrame = 0}) => barStartFrame(
      bar: bar,
      ticksPerBar: 4,
      intervalMicros: 487805,
      sampleRate: 48000,
      epochFrame: epochFrame,
    );

    test('keeps the initial bar boundary', () {
      expect(startFrame(bar: 0), 0);
    });

    test('rounds the first bar boundary', () {
      expect(startFrame(bar: 1), 93659);
    });

    test('avoids accumulated rounding drift', () {
      expect(startFrame(bar: 100), 9365856);
    });

    test('offsets the bar boundary by the epoch', () {
      expect(startFrame(bar: 1, epochFrame: 1000), 94659);
    });
  });
}
