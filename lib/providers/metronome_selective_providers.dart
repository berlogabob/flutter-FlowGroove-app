/// Selective providers for metronome state
///
/// These providers enable granular rebuilds by exposing only specific fields
/// from the main metronomeProvider, reducing unnecessary widget rebuilds.
///
/// Usage:
/// ```dart
/// // Instead of watching full state (rebuilt on every beat):
/// final state = ref.watch(metronomeProvider);
///
/// // Watch only what you need:
/// final bpm = ref.watch(metronomeBpmProvider);
/// final isPlaying = ref.watch(metronomeIsPlayingProvider);
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/metronome_provider.dart';
import '../models/beat_mode.dart';
import '../models/song.dart';
import '../models/setlist.dart';

/// Provider for BPM only (doesn't rebuild on beat changes)
final metronomeBpmProvider = Provider<int>((ref) {
  return ref.watch(metronomeProvider).bpm;
});

/// Provider for play state only (doesn't rebuild on BPM/beat changes)
final metronomeIsPlayingProvider = Provider<bool>((ref) {
  return ref.watch(metronomeProvider).isPlaying;
});

/// Provider for current beat only (rebuilt only when beat value changes)
final metronomeCurrentBeatProvider = Provider<int>((ref) {
  return ref.watch(metronomeProvider.select((s) => s.currentBeat));
});

/// Provider for time signature only
final metronomeTimeSignatureProvider = Provider((ref) {
  return ref.watch(metronomeProvider).timeSignature;
});

/// Provider for accent beats count
final metronomeAccentBeatsProvider = Provider<int>((ref) {
  return ref.watch(metronomeProvider).accentBeats;
});

/// Provider for regular beats (subdivisions) count
final metronomeRegularBeatsProvider = Provider<int>((ref) {
  return ref.watch(metronomeProvider).regularBeats;
});

/// Provider for beat modes 2D grid
final metronomeBeatModesProvider = Provider<List<List<BeatMode>>>((ref) {
  return ref.watch(metronomeProvider).beatModes;
});

/// Provider for loaded song (null if none)
final metronomeLoadedSongProvider = Provider<Song?>((ref) {
  return ref.watch(metronomeProvider).loadedSong;
});

/// Provider for loaded setlist (null if none)
final metronomeLoadedSetlistProvider = Provider<Setlist?>((ref) {
  return ref.watch(metronomeProvider).loadedSetlist;
});

/// Provider for wave type
final metronomeWaveTypeProvider = Provider<String>((ref) {
  return ref.watch(metronomeProvider).waveType;
});

/// Provider for volume
final metronomeVolumeProvider = Provider<double>((ref) {
  return ref.watch(metronomeProvider).volume;
});

/// Provider for accent enabled state
final metronomeAccentEnabledProvider = Provider<bool>((ref) {
  return ref.watch(metronomeProvider).accentEnabled;
});

/// Provider for accent frequency
final metronomeAccentFrequencyProvider = Provider<double>((ref) {
  return ref.watch(metronomeProvider).accentFrequency;
});

/// Provider for beat frequency
final metronomeBeatFrequencyProvider = Provider<double>((ref) {
  return ref.watch(metronomeProvider).beatFrequency;
});
