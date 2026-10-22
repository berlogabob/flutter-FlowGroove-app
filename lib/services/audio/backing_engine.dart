import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodCall;

class BackingStems {
  const BackingStems({
    required this.stems,
    required this.names,
    required this.sampleRate,
    required this.renderBpm,
    required this.ticksPerBar,
    required this.intervalMicros,
  });

  final List<Int16List> stems;
  final List<String> names;
  final int sampleRate;
  final double renderBpm;
  final int ticksPerBar;
  final int intervalMicros;
}

enum BackingKind { launch, stop }

class BackingCommand {
  const BackingCommand({
    required this.token,
    required this.kind,
    this.fromBar = 0,
    this.bars = 0,
    this.loop = true,
    required this.atBar,
  });

  final int token;
  final BackingKind kind;
  final int fromBar;
  final int bars;
  final bool loop;
  final int atBar;
}

enum BackingStateKind { queued, playing, stopped }

class BackingState {
  const BackingState(this.token, this.kind, this.bar);

  final int token;
  final BackingStateKind kind;
  final int bar;
}

/// Set by the Android engine; the click client forwards native backing calls here.
Future<void> Function(MethodCall call)? backingNativeSink;

abstract class BackingEngine {
  Future<int> engineSampleRate();
  Future<void> load(BackingStems stems);
  Future<void> command(BackingCommand c);
  void setGain(int stem, double gain);
  Future<void> clear();
  Stream<BackingState> get states;
  Stream<int> get bars;
  Future<void> dispose();
}
