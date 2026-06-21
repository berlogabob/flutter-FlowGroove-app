import 'package:flutter/foundation.dart';
import '../../../models/beat_mode.dart';

@immutable
class RenderConfig {
  const RenderConfig({
    required this.bpm,
    required this.beats,
    required this.subdivisions,
    required this.beatModes,
    required this.accentEnabled,
    required this.accentFrequency,
    required this.beatFrequency,
    required this.volume,
    required this.countInBars,
    required this.latencyOffsetFrames,
  });

  final int bpm;
  final int beats;            // beats per bar
  final int subdivisions;     // per beat
  final List<List<BeatMode>> beatModes;
  final bool accentEnabled;
  final double accentFrequency;
  final double beatFrequency;
  final double volume;
  final int countInBars;
  final int latencyOffsetFrames;

  int get safeBeats => beats.clamp(1, 12);
  int get safeSubdivisions => subdivisions.clamp(1, 12);
  int get totalTicks => safeBeats * safeSubdivisions;
}
