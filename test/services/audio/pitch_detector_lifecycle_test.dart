import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/pitch_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('denied permission prevents capture start', () async {
    final input = _FakeAudioInput(TunerPermissionState.denied);
    final detector = PitchDetector(audioInput: input);

    await expectLater(detector.startListening(), throwsStateError);
    expect(input.startCount, 0);
    await detector.dispose();
  });

  test('stop and dispose release microphone exactly once', () async {
    final input = _FakeAudioInput(TunerPermissionState.granted);
    final detector = PitchDetector(audioInput: input);

    await detector.startListening();
    expect(detector.isListening, isTrue);
    expect(input.startCount, 1);

    await detector.stopListening();
    await detector.stopListening();
    expect(input.stopCount, 1);
    expect(detector.isListening, isFalse);

    await detector.dispose();
    await detector.dispose();
    expect(input.disposeCount, 1);
  });
}

class _FakeAudioInput implements AudioInput {
  final TunerPermissionState permission;
  final StreamController<Uint8List> controller = StreamController<Uint8List>();
  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  _FakeAudioInput(this.permission);

  @override
  bool isRecording = false;

  @override
  int get sampleRate => 44100;

  @override
  Future<TunerPermissionState> permissionStatus() async => permission;

  @override
  Future<TunerPermissionState> requestPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start() async {
    startCount++;
    isRecording = true;
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    if (!isRecording) return;
    stopCount++;
    isRecording = false;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await stop();
    unawaited(controller.close());
  }
}
