import 'dart:math' as math;
import 'dart:typed_data';

import '../../../utils/bar_math.dart';
import '../backing_engine.dart';

BackingStems diagnosticStems({
  required int sampleRate,
  required int intervalMicros,
  required int ticksPerBar,
  required double renderBpm,
  required int bars,
}) {
  if (sampleRate <= 6000 ||
      intervalMicros <= 0 ||
      ticksPerBar <= 0 ||
      !renderBpm.isFinite ||
      renderBpm <= 0 ||
      bars <= 0) {
    throw ArgumentError('Invalid diagnostic tempo or grid');
  }
  final tickFrames = tickIntervalFrames(intervalMicros.toDouble(), sampleRate);
  final ticksPerBeat = math.max(
    1,
    (60000000 / renderBpm / intervalMicros).round(),
  );
  final pcm = Int16List((bars * ticksPerBar * tickFrames).round());
  final burstFrames = (sampleRate * 0.020).round();
  for (var tick = 0; tick < bars * ticksPerBar; tick += ticksPerBeat) {
    final start = (tick * tickFrames).round();
    for (var i = 0; i < burstFrames && start + i < pcm.length; i++) {
      pcm[start + i] = (16000 * math.sin(2 * math.pi * 3000 * i / sampleRate))
          .round();
    }
  }
  return BackingStems(
    stems: [pcm],
    names: const ['Sync test'],
    sampleRate: sampleRate,
    renderBpm: renderBpm,
    ticksPerBar: ticksPerBar,
    intervalMicros: intervalMicros,
  );
}
