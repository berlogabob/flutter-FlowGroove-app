import 'dart:typed_data';

import 'package:flowgroove/services/audio/engine/audio_sink.dart';
import 'package:flowgroove/services/audio/engine/sinks/soloud_sink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // SoLoud cannot init in the headless test VM; assert the class satisfies the
  // contract and that pushFrames before open is a safe no-op (no throw).
  test('NativeSoLoudSink is an AudioSink and tolerates pre-open pushFrames', () {
    final sink = NativeSoLoudSink();
    expect(sink, isA<AudioSink>());
    expect(() => sink.pushFrames(Float32List(0)), returnsNormally);
  });
}
