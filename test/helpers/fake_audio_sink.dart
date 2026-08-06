import 'dart:async';
import 'dart:typed_data';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';

class FakeAudioSink implements AudioSink {
  final List<Float32List> pushed = [];
  int openCount = 0;
  int recoverCount = 0;
  int? lastRecoverFrame;

  /// Frames pushed / played, so [framesQueued] models a real draining buffer
  /// instead of growing forever.
  int pushedFrames = 0;
  int consumedFrames = 0;

  /// Event emitted at the end of [recover] — the seam that reproduces a sink
  /// whose recovery success re-triggers recovery (#151 RC2).
  SinkEvent? recoverEmits;

  /// Held open inside [recover] so a test can assert nothing pumps meanwhile.
  Completer<void>? recoverGate;

  /// Proves diagnostics can never break playback.
  bool framesQueuedThrows = false;

  final _events = StreamController<SinkEvent>.broadcast();

  void emit(SinkEvent e) => _events.add(e);

  /// Simulate the device playing [frames] worth of audio.
  void drain(int frames) => consumedFrames += frames;

  @override
  Future<void> open({required int sampleRate, required int channels}) async =>
      openCount++;

  @override
  void pushFrames(Float32List pcm) {
    pushed.add(pcm);
    pushedFrames += pcm.length;
  }

  @override
  int get framesQueued {
    if (framesQueuedThrows) throw StateError('framesQueued exploded');
    final q = pushedFrames - consumedFrames;
    return q > 0 ? q : 0;
  }

  @override
  Stream<SinkEvent> get events => _events.stream;

  @override
  Future<void> recover({required int atFrame}) async {
    recoverCount++;
    lastRecoverFrame = atFrame;
    if (recoverGate != null) await recoverGate!.future;
    if (recoverEmits case final e?) _events.add(e);
  }

  @override
  Future<void> close() async => _events.close();
}
