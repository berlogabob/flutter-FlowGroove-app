/// Global tone configuration provider
///
/// Manages user's metronome tone preferences with persistence via SharedPreferences.
/// Loaded once at startup, then available throughout app lifetime.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/metronome_tone_config.dart';
import '../services/audio/metronome_sample_generator.dart';

/// Provider for global tone configuration
final globalToneConfigProvider =
    NotifierProvider<ToneConfigNotifier, MetronomeToneConfig>(() {
  return ToneConfigNotifier();
});

/// Manages tone configuration state and persistence
class ToneConfigNotifier extends Notifier<MetronomeToneConfig> {
  @override
  MetronomeToneConfig build() {
    _loadFromPrefs();
    return MetronomeToneConfig.classic();
  }

  /// Load configuration from SharedPreferences
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('metronome_tone_config');

      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = MetronomeToneConfig.fromJson(json);
      }
    } catch (e) {
      // Use default config on error - state already set in build()
    }
  }

  /// Save configuration to SharedPreferences
  Future<void> saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('metronome_tone_config', jsonEncode(state.toJson()));
    } catch (e) {
      // Silently fail - config will revert to default on next launch
    }
  }

  /// Apply preset by name
  Future<void> setPreset(String presetName) async {
    state = MetronomeToneConfig.fromPresetName(presetName);
    await saveToPrefs();
  }

  /// Update individual frequency
  Future<void> updateFrequency({
    required String frequencyType,
    required double value,
  }) async {
    MetronomeToneConfig? newConfig;

    switch (frequencyType) {
      case 'mainRegular':
        newConfig = state.copyWith(mainRegularFreq: value);
        break;
      case 'mainAccent':
        newConfig = state.copyWith(mainAccentFreq: value);
        break;
      case 'subRegular':
        newConfig = state.copyWith(subRegularFreq: value);
        break;
      case 'subAccent':
        newConfig = state.copyWith(subAccentFreq: value);
        break;
      case 'dividerRegular':
        newConfig = state.copyWith(dividerRegularFreq: value);
        break;
      case 'dividerAccent':
        newConfig = state.copyWith(dividerAccentFreq: value);
        break;
    }

    if (newConfig != null) {
      state = newConfig;
      await saveToPrefs();
    }
  }

  /// Update wave type
  Future<void> setWaveType(String waveType) async {
    state = state.copyWith(waveType: waveType);
    await saveToPrefs();
  }

  /// Update volume
  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
    await saveToPrefs();
  }

  /// Reset to default (classic) preset
  Future<void> resetToDefault() async {
    state = MetronomeToneConfig.classic();
    await saveToPrefs();
  }

  /// Test current configuration (returns sample bytes)
  Future<Uint8List> testCurrentConfig() async {
    final generator = MetronomeSampleGenerator();
    await generator.generateAllSamples(state);
    return generator.getSample('main_regular');
  }
}
