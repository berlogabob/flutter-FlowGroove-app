import 'dart:io';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flowgroove/services/audio/backing_engine_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.flowgroove/metronome');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory cache;
  late PlatformBackingEngine engine;
  late List<MethodCall> calls;

  BackingStems stems() => BackingStems(
    stems: [
      Int16List.fromList([0, 32767, -32768, -1, 0x1234]),
      Int16List.fromList([256, -256]),
    ],
    names: const ['Drums', 'Bass'],
    sampleRate: 48000,
    renderBpm: 137,
    ticksPerBar: 7,
    intervalMicros: 437956,
  );

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('backing_engine_test_');
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'engineSampleRate') return 48000;
      return null;
    });
    engine = PlatformBackingEngine(channel: channel, cacheDirectory: cache);
  });

  tearDown(() async {
    await engine.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    await cache.delete(recursive: true);
  });

  test('queries the engine sample rate', () async {
    expect(await engine.engineSampleRate(), 48000);
    expect(calls.single.method, 'engineSampleRate');
  });

  test(
    'load sends cache paths and timing with raw little-endian PCM',
    () async {
      await engine.load(stems());

      final call = calls.single;
      expect(call.method, 'backingLoad');
      final args = call.arguments as Map<Object?, Object?>;
      final paths = (args['paths']! as List<Object?>).cast<String>();
      expect(args, {
        'paths': paths,
        'sampleRate': 48000,
        'renderBpm': 137.0,
        'ticksPerBar': 7,
        'intervalMicros': 437956,
      });
      expect(paths, hasLength(2));
      for (final path in paths) {
        expect(path, startsWith('${cache.path}/'));
      }
      expect(await File(paths[0]).readAsBytes(), [
        0,
        0,
        255,
        127,
        0,
        128,
        255,
        255,
        0x34,
        0x12,
      ]);
      expect(await File(paths[1]).readAsBytes(), [0, 1, 0, 255]);
    },
  );

  test('sends every command field and stem gain', () async {
    for (final kind in BackingKind.values) {
      await engine.command(
        BackingCommand(
          token: 42,
          kind: kind,
          fromBar: 2,
          bars: 8,
          loop: false,
          atBar: 12,
        ),
      );
      expect(calls.last.method, 'backingCommand');
      expect(calls.last.arguments, {
        'token': 42,
        'kind': kind.name,
        'fromBar': 2,
        'bars': 8,
        'loop': false,
        'atBar': 12,
      });
    }
    engine.setGain(1, 0.25);
    await Future<void>.delayed(Duration.zero);
    expect(calls.last.method, 'backingGain');
    expect(calls.last.arguments, {'stem': 1, 'gain': 0.25});
  });

  test('forwarded native states and bars feed broadcast streams', () async {
    // Simulate the existing metronome handler forwarding backing events.
    channel.setMethodCallHandler(engine.handleMethodCall);
    addTearDown(() => channel.setMethodCallHandler(null));
    Future<void> incoming(MethodCall call) async {
      final response = await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(call),
        null,
      );
      channel.codec.decodeEnvelope(response!);
    }

    final states = <BackingState>[];
    final bars = <int>[];
    final stateSubscription = engine.states.listen(states.add);
    final barSubscription = engine.bars.listen(bars.add);
    addTearDown(stateSubscription.cancel);
    addTearDown(barSubscription.cancel);

    for (final kind in BackingStateKind.values) {
      await incoming(
        MethodCall('backingState', {
          'token': 42,
          'state': kind.name,
          'bar': 12,
        }),
      );
    }
    await incoming(const MethodCall('bar', {'index': 13}));
    await incoming(const MethodCall('tick', {'index': 4}));
    await Future<void>.delayed(Duration.zero);

    expect(states.map((state) => state.kind), BackingStateKind.values);
    expect(
      states.every((state) => state.token == 42 && state.bar == 12),
      isTrue,
    );
    expect(bars, [13]);
  });

  test('clear tells native engine before deleting its files', () async {
    await engine.load(stems());
    final paths =
        ((calls.single.arguments as Map<Object?, Object?>)['paths']!
                as List<Object?>)
            .cast<String>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'backingClear') {
        for (final path in paths) {
          expect(File(path).existsSync(), isTrue);
        }
      }
      return null;
    });

    await engine.clear();
    expect(calls.last.method, 'backingClear');
    for (final path in paths) {
      expect(File(path).existsSync(), isFalse);
    }
    expect(await cache.list().toList(), isEmpty);
    messenger.setMockMethodCallHandler(channel, (_) async => null);
  });

  test('failed load removes newly written files', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'backingLoad') {
        throw PlatformException(code: 'invalid_backing');
      }
      return null;
    });
    await expectLater(engine.load(stems()), throwsA(isA<PlatformException>()));
    expect(await cache.list().toList(), isEmpty);
  });

  test('reloading replaces files without leaving old cache entries', () async {
    await engine.load(stems());
    final firstDirectory = (await cache.list().toList()).single.path;
    await engine.load(stems());
    final entries = await cache.list().toList();
    expect(entries, hasLength(1));
    expect(entries.single.path, isNot(firstDirectory));
    expect(Directory(firstDirectory).existsSync(), isFalse);
  });
}
