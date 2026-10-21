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
  final k = ((nowFrame + leadFrames - epochFrame) / (unit * tickFrames)).ceil();
  return epochFrame + ((k < 0 ? 0 : k) * unit * tickFrames).round();
}
