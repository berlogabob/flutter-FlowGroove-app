enum Quantize { now, beat, bar }

int quantizeFrame({
  required Quantize mode,
  required int nowFrame,
  required int leadFrames,
  required int epochFrame,
  required int ticksPerBeat,
  required int ticksPerBar,
  required double tickFrames,
}) {
  if (mode == Quantize.now) return nowFrame + leadFrames;

  final unit = mode == Quantize.beat ? ticksPerBeat : ticksPerBar;
  var k = ((nowFrame + leadFrames - epochFrame) / (unit * tickFrames)).ceil();
  // Keep a boundary that rounds to the requested frame.
  if (k > 0 &&
      epochFrame + ((k - 1) * unit * tickFrames).round() ==
          nowFrame + leadFrames) {
    k--;
  }
  return epochFrame + ((k < 0 ? 0 : k) * unit * tickFrames).round();
}
