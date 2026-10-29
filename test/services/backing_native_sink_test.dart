import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flowgroove/services/audio/backing_engine_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.flowgroove/metronome'),
        (_) async => null,
      );
  test('native bar and backingState calls reach the engine streams', () async {
    final engine = PlatformBackingEngine();
    final bars = expectLater(engine.bars, emits(3));
    final states = expectLater(
      engine.states,
      emits(
        isA<BackingState>().having(
          (s) => s.kind,
          'kind',
          BackingStateKind.playing,
        ),
      ),
    );
    await backingNativeSink!(const MethodCall('bar', {'index': 3}));
    await backingNativeSink!(
      const MethodCall('backingState', {
        'token': 1,
        'state': 'playing',
        'bar': 2,
      }),
    );
    await bars;
    await states;
    await engine.dispose();
    expect(backingNativeSink, isNull);
  });
}
