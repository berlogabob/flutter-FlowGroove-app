/// When a launched pad starts. [block] waits for the section that is playing to
/// finish, so the next block begins exactly where the previous one ends; the
/// frame helpers below treat it as [bar] (the provider resolves the block end).
enum Quantize {
  now,
  beat,
  bar,
  block;

  String get label => switch (this) {
    Quantize.now => 'Now',
    Quantize.beat => 'Beat',
    Quantize.bar => 'Bar',
    Quantize.block => 'Block',
  };

  /// Order the transport button cycles through. Beat and now are not offered:
  /// backing commands start on whole bars, so they would behave like bar.
  Quantize get next => switch (this) {
    Quantize.bar => Quantize.block,
    _ => Quantize.bar,
  };
}

int nextBoundaryFrame({
  required int nowFrame,
  required Quantize q,
  required double tickFrames,
  required int ticksPerBeat,
  required int ticksPerBar,
  int leadFrames = 0,
  int epochFrame = 0,
}) {
  if (q == Quantize.now) return nowFrame + leadFrames;

  final unit = q == Quantize.beat ? ticksPerBeat : ticksPerBar;
  var k = ((nowFrame + leadFrames - epochFrame) / (unit * tickFrames)).ceil();
  // Keep a boundary that rounds to the requested frame.
  if (k > 0 &&
      epochFrame + ((k - 1) * unit * tickFrames).round() ==
          nowFrame + leadFrames) {
    k--;
  }
  return epochFrame + ((k < 0 ? 0 : k) * unit * tickFrames).round();
}

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
