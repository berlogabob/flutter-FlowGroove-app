import 'dart:async';
import 'dart:typed_data';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';

class FakeAudioSink implements AudioSink {
  final List<Float32List> pushed = [];
  int openCount = 0;
  int recoverCount = 0;
  int? lastRecoverFrame;
  int queued = 0;
  final _events = StreamController<SinkEvent>.broadcast();

  void emit(SinkEvent e) => _events.add(e);

  @override
  Future<void> open({required int sampleRate, required int channels}) async => openCount++;
  @override
  void pushFrames(Float32List pcm) {
    pushed.add(pcm);
    queued += pcm.length;
  }
  @override
  int get framesQueued => queued;
  @override
  Stream<SinkEvent> get events => _events.stream;
  @override
  Future<void> recover({required int atFrame}) async {
    recoverCount++;
    lastRecoverFrame = atFrame;
  }
  @override
  Future<void> close() async => _events.close();
}
