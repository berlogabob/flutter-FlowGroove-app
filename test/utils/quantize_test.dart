import 'package:flowgroove/utils/quantize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextBoundaryFrame', () {
    int quantize({
      Quantize mode = Quantize.bar,
      required int nowFrame,
      int leadFrames = 0,
      int epochFrame = 0,
    }) => nextBoundaryFrame(
      q: mode,
      nowFrame: nowFrame,
      leadFrames: leadFrames,
      epochFrame: epochFrame,
      ticksPerBeat: 1,
      ticksPerBar: 4,
      tickFrames: 23414.64,
    );

    test('keeps the initial bar boundary', () {
      expect(quantize(nowFrame: 0), 0);
    });

    test('rounds up to the first bar', () {
      expect(quantize(nowFrame: 1), 93659);
    });

    test('keeps the rounded bar boundary', () {
      expect(quantize(nowFrame: 93659), 93659);
    });

    test('advances after the rounded bar boundary', () {
      expect(quantize(nowFrame: 93660), 187317);
    });

    test('rounds up to the first beat', () {
      expect(quantize(mode: Quantize.beat, nowFrame: 1), 23415);
    });

    test('includes lead frames when quantizing to a bar', () {
      expect(quantize(nowFrame: 0, leadFrames: 100), 93659);
    });

    test('adds lead frames in now mode', () {
      expect(quantize(mode: Quantize.now, nowFrame: 10, leadFrames: 50), 60);
    });

    test('keeps the epoch bar boundary', () {
      expect(quantize(nowFrame: 1000, epochFrame: 1000), 1000);
    });
  });
}
