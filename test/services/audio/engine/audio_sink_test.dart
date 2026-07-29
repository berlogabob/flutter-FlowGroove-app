import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/engine/audio_sink.dart';
import '../../../helpers/fake_audio_sink.dart';

void main() {
  test('FakeAudioSink records pushed frames and recover calls', () async {
    final sink = FakeAudioSink();
    await sink.open(sampleRate: 48000, channels: 1);
    final frames = Float32List.fromList([0.1, 0.2]);
    sink.pushFrames(frames);
    await sink.recover(atFrame: 1234);
    expect(sink.openCount, 1);
    final actual = sink.pushed.single;
    expect(actual.length, 2);
    expect(actual[0], closeTo(0.1, 1e-6));
    expect(actual[1], closeTo(0.2, 1e-6));
    expect(sink.lastRecoverFrame, 1234);
  });

  test('FakeAudioSink forwards emitted events on the stream', () async {
    final sink = FakeAudioSink();
    final got = <SinkEventType>[];
    sink.events.listen((e) => got.add(e.type));
    sink.emit(const SinkEvent(SinkEventType.deviceChanged));
    await Future<void>.delayed(Duration.zero);
    expect(got, [SinkEventType.deviceChanged]);
  });
}
