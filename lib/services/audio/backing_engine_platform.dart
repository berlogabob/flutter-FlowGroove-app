import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'backing_engine.dart';

class PlatformBackingEngine implements BackingEngine {
  PlatformBackingEngine({MethodChannel? channel, this.cacheDirectory})
    : _channel = channel ?? const MethodChannel('com.flowgroove/metronome') {
    backingNativeSink = handleMethodCall;
  }

  final MethodChannel _channel;
  final Directory? cacheDirectory;
  final _states = StreamController<BackingState>.broadcast();
  final _bars = StreamController<int>.broadcast();
  final _directories = <Directory>[];

  @override
  Stream<BackingState> get states => _states.stream;

  @override
  Stream<int> get bars => _bars.stream;

  @override
  Future<int> engineSampleRate() async =>
      (await _channel.invokeMethod<int>('engineSampleRate'))!;

  @override
  Future<void> load(BackingStems stems) async {
    final cache = cacheDirectory ?? await getApplicationCacheDirectory();
    final directory = await cache.createTemp('backing_');
    _directories.add(directory);
    try {
      final paths = <String>[];
      for (var i = 0; i < stems.stems.length; i++) {
        final samples = stems.stems[i];
        final bytes = ByteData(samples.length * 2);
        for (var j = 0; j < samples.length; j++) {
          bytes.setInt16(j * 2, samples[j], Endian.little);
        }
        final file = File('${directory.path}/$i.pcm');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        paths.add(file.path);
      }
      await _channel.invokeMethod<void>('backingLoad', {
        'paths': paths,
        'sampleRate': stems.sampleRate,
        'renderBpm': stems.renderBpm,
        'ticksPerBar': stems.ticksPerBar,
        'intervalMicros': stems.intervalMicros,
      });
    } catch (_) {
      await directory.delete(recursive: true);
      _directories.remove(directory);
      rethrow;
    }
    for (final previous in _directories.toList()) {
      if (previous != directory) {
        await previous.delete(recursive: true);
        _directories.remove(previous);
      }
    }
  }

  @override
  // cancel: fromBar carries the token to drop (native side maps it).
  Future<void> command(BackingCommand c) =>
      _channel.invokeMethod<void>('backingCommand', {
        'token': c.token,
        'kind': c.kind.name,
        'fromBar': c.fromBar,
        'bars': c.bars,
        'loop': c.loop,
        'atBar': c.atBar,
      });

  @override
  void setGain(int stem, double gain) {
    unawaited(
      _channel.invokeMethod<void>('backingGain', {'stem': stem, 'gain': gain}),
    );
  }

  /// Forward backing calls here from the metronome channel's existing handler.
  Future<void> handleMethodCall(MethodCall call) async {
    if (_states.isClosed) return;
    switch (call.method) {
      case 'backingState':
        final args = call.arguments as Map<Object?, Object?>;
        _states.add(
          BackingState(
            args['token']! as int,
            BackingStateKind.values.byName(args['state']! as String),
            args['bar']! as int,
          ),
        );
      case 'bar':
        final args = call.arguments as Map<Object?, Object?>;
        _bars.add(args['index']! as int);
    }
  }

  @override
  Future<void> clear() async {
    await _channel.invokeMethod<void>('backingClear');
    for (final directory in _directories.toList()) {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
      _directories.remove(directory);
    }
  }

  @override
  Future<void> dispose() async {
    if (backingNativeSink == handleMethodCall) {
      backingNativeSink = null;
    }
    try {
      await clear();
    } finally {
      await _states.close();
      await _bars.close();
    }
  }
}
