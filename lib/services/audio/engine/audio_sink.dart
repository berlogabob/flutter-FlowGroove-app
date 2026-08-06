import 'dart:typed_data';

/// [recovered] is emitted by a sink when [AudioSink.recover] finished and left
/// the sink usable. It must NOT be [deviceChanged]: the scheduler answers
/// `deviceChanged` by recovering, so reusing it for success makes recovery
/// re-enter itself forever (each cycle tearing down the audio device).
enum SinkEventType {
  deviceChanged,
  recovered,
  underrun,
  error,
  focusLost,
  focusGained,
}

class SinkEvent {
  const SinkEvent(this.type, [this.detail]);
  final SinkEventType type;
  final Object? detail;
}

abstract class AudioSink {
  Future<void> open({required int sampleRate, required int channels});
  void pushFrames(Float32List pcm);

  /// Frames pushed but not yet played. Diagnostics only — nothing gates
  /// rendering on it. Implementations must never throw and must return 0
  /// when the true depth is unknown.
  int get framesQueued;
  Stream<SinkEvent> get events;
  Future<void> recover({required int atFrame});
  Future<void> close();
}
