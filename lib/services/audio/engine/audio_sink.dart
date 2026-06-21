import 'dart:typed_data';

enum SinkEventType { deviceChanged, underrun, error, focusLost, focusGained }

class SinkEvent {
  const SinkEvent(this.type, [this.detail]);
  final SinkEventType type;
  final Object? detail;
}

abstract class AudioSink {
  Future<void> open({required int sampleRate, required int channels});
  void pushFrames(Float32List pcm);
  int get framesQueued;
  Stream<SinkEvent> get events;
  Future<void> recover({required int atFrame});
  Future<void> close();
}
