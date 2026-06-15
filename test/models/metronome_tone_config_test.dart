/// Unit tests for MetronomeToneConfig
///
/// Tests cover:
/// - Constructor and default values
/// - Preset factories
/// - JSON serialization/deserialization
/// - copyWith method
/// - getFrequency method
/// - isValid getter
/// - fromPresetName method
library;

import 'package:flowgroove/models/metronome_tone_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetronomeToneConfig', () {
    // Test constructor
    test('creates instance with required fields', () {
      const config = MetronomeToneConfig(
        mainRegularFreq: 1600,
        mainAccentFreq: 2060,
        subRegularFreq: 800,
        subAccentFreq: 1030,
        dividerRegularFreq: 1100,
        dividerAccentFreq: 1400,
        waveType: 'sine',
        volume: 0.75,
      );

      expect(config.mainRegularFreq, 1600.0);
      expect(config.mainAccentFreq, 2060.0);
      expect(config.subRegularFreq, 800.0);
      expect(config.subAccentFreq, 1030.0);
      expect(config.dividerRegularFreq, 1100.0);
      expect(config.dividerAccentFreq, 1400.0);
      expect(config.waveType, 'sine');
      expect(config.volume, 0.75);
    });

    // Test presets
    test('classic preset has correct values', () {
      final config = MetronomeToneConfig.classic();

      expect(config.mainRegularFreq, 1600.0);
      expect(config.mainAccentFreq, 2060.0);
      expect(config.subRegularFreq, 800.0);
      expect(config.subAccentFreq, 1030.0);
      expect(config.dividerRegularFreq, 1100.0);
      expect(config.dividerAccentFreq, 1400.0);
      expect(config.waveType, 'sine');
      expect(config.volume, 0.75);
    });

    test('subtle preset has correct values', () {
      final config = MetronomeToneConfig.subtle();

      expect(config.mainRegularFreq, 1200.0);
      expect(config.mainAccentFreq, 1600.0);
      expect(config.subRegularFreq, 600.0);
      expect(config.subAccentFreq, 800.0);
      expect(config.dividerRegularFreq, 900.0);
      expect(config.dividerAccentFreq, 1200.0);
      expect(config.waveType, 'sine');
      expect(config.volume, 0.5);
    });

    test('extreme preset has correct values', () {
      final config = MetronomeToneConfig.extreme();

      expect(config.mainRegularFreq, 2000.0);
      expect(config.mainAccentFreq, 2800.0);
      expect(config.subRegularFreq, 1000.0);
      expect(config.subAccentFreq, 1400.0);
      expect(config.dividerRegularFreq, 1500.0);
      expect(config.dividerAccentFreq, 2000.0);
      expect(config.waveType, 'square');
      expect(config.volume, 1.0);
    });

    test('woodBlock preset has correct values', () {
      final config = MetronomeToneConfig.woodBlock();

      expect(config.mainRegularFreq, 1800.0);
      expect(config.mainAccentFreq, 2400.0);
      expect(config.subRegularFreq, 900.0);
      expect(config.subAccentFreq, 1200.0);
      expect(config.dividerRegularFreq, 1300.0);
      expect(config.dividerAccentFreq, 1700.0);
      expect(config.waveType, 'triangle');
      expect(config.volume, 0.8);
    });

    test('electronic preset has correct values', () {
      final config = MetronomeToneConfig.electronic();

      expect(config.mainRegularFreq, 2200.0);
      expect(config.mainAccentFreq, 3000.0);
      expect(config.subRegularFreq, 1100.0);
      expect(config.subAccentFreq, 1500.0);
      expect(config.dividerRegularFreq, 1600.0);
      expect(config.dividerAccentFreq, 2200.0);
      expect(config.waveType, 'sawtooth');
      expect(config.volume, 0.9);
    });

    // Test fromPresetName
    test('fromPresetName returns correct presets', () {
      expect(MetronomeToneConfig.fromPresetName('Classic'), equals(MetronomeToneConfig.classic()));
      expect(MetronomeToneConfig.fromPresetName('Subtle'), equals(MetronomeToneConfig.subtle()));
      expect(MetronomeToneConfig.fromPresetName('Extreme'), equals(MetronomeToneConfig.extreme()));
      expect(MetronomeToneConfig.fromPresetName('Wood Block'), equals(MetronomeToneConfig.woodBlock()));
      expect(MetronomeToneConfig.fromPresetName('woodblock'), equals(MetronomeToneConfig.woodBlock()));
      expect(MetronomeToneConfig.fromPresetName('Electronic'), equals(MetronomeToneConfig.electronic()));
      expect(MetronomeToneConfig.fromPresetName('Unknown'), equals(MetronomeToneConfig.classic()));
    });

    // Test copyWith
    test('copyWith creates modified copy', () {
      final original = MetronomeToneConfig.classic();
      final modified = original.copyWith(mainRegularFreq: 1800);

      expect(modified.mainRegularFreq, 1800.0);
      expect(modified.mainAccentFreq, original.mainAccentFreq); // Unchanged
      expect(modified.waveType, original.waveType); // Unchanged
    });

    // Test getFrequency
    test('getFrequency returns correct frequencies', () {
      final config = MetronomeToneConfig.classic();

      // Main beat, regular
      expect(config.getFrequency(isMainBeat: true, isSubdivision: false, isAccented: false), 1600.0);

      // Main beat, accented
      expect(config.getFrequency(isMainBeat: true, isSubdivision: false, isAccented: true), 2060.0);

      // Subdivision, regular
      expect(config.getFrequency(isMainBeat: false, isSubdivision: true, isAccented: false), 800.0);

      // Subdivision, accented
      expect(config.getFrequency(isMainBeat: false, isSubdivision: true, isAccented: true), 1030.0);

      // Divider, regular
      expect(config.getFrequency(isMainBeat: false, isSubdivision: false, isAccented: false), 1100.0);

      // Divider, accented
      expect(config.getFrequency(isMainBeat: false, isSubdivision: false, isAccented: true), 1400.0);
    });

    // Test isValid
    test('isValid returns true for valid config', () {
      final config = MetronomeToneConfig.classic();
      expect(config.isValid, isTrue);
    });

    test('isValid returns false for out-of-range frequencies', () {
      const configLow = MetronomeToneConfig(
        mainRegularFreq: 100, // Below 200
        mainAccentFreq: 2060,
        subRegularFreq: 800,
        subAccentFreq: 1030,
        dividerRegularFreq: 1100,
        dividerAccentFreq: 1400,
        waveType: 'sine',
        volume: 0.75,
      );
      expect(configLow.isValid, isFalse);

      const configHigh = MetronomeToneConfig(
        mainRegularFreq: 5000, // Above 4000
        mainAccentFreq: 2060,
        subRegularFreq: 800,
        subAccentFreq: 1030,
        dividerRegularFreq: 1100,
        dividerAccentFreq: 1400,
        waveType: 'sine',
        volume: 0.75,
      );
      expect(configHigh.isValid, isFalse);
    });

    test('isValid returns false for out-of-range volume', () {
      const configLow = MetronomeToneConfig(
        mainRegularFreq: 1600,
        mainAccentFreq: 2060,
        subRegularFreq: 800,
        subAccentFreq: 1030,
        dividerRegularFreq: 1100,
        dividerAccentFreq: 1400,
        waveType: 'sine',
        volume: -0.1, // Below 0.0
      );
      expect(configLow.isValid, isFalse);

      const configHigh = MetronomeToneConfig(
        mainRegularFreq: 1600,
        mainAccentFreq: 2060,
        subRegularFreq: 800,
        subAccentFreq: 1030,
        dividerRegularFreq: 1100,
        dividerAccentFreq: 1400,
        waveType: 'sine',
        volume: 1.1, // Above 1.0
      );
      expect(configHigh.isValid, isFalse);
    });

    test('isValid returns false for invalid wave type', () {
      const config = MetronomeToneConfig(
        mainRegularFreq: 1600,
        mainAccentFreq: 2060,
        subRegularFreq: 800,
        subAccentFreq: 1030,
        dividerRegularFreq: 1100,
        dividerAccentFreq: 1400,
        waveType: 'invalid', // Invalid wave type
        volume: 0.75,
      );
      expect(config.isValid, isFalse);
    });

    // Test JSON serialization
    test('toJson returns correct map', () {
      final config = MetronomeToneConfig.classic();
      final json = config.toJson();

      expect(json['mainRegularFreq'], 1600.0);
      expect(json['mainAccentFreq'], 2060.0);
      expect(json['subRegularFreq'], 800.0);
      expect(json['subAccentFreq'], 1030.0);
      expect(json['dividerRegularFreq'], 1100.0);
      expect(json['dividerAccentFreq'], 1400.0);
      expect(json['waveType'], 'sine');
      expect(json['volume'], 0.75);
    });

    test('fromJson creates instance with correct values', () {
      final json = <String, dynamic>{
        'mainRegularFreq': 1800.0,
        'mainAccentFreq': 2400.0,
        'subRegularFreq': 900.0,
        'subAccentFreq': 1200.0,
        'dividerRegularFreq': 1300.0,
        'dividerAccentFreq': 1700.0,
        'waveType': 'triangle',
        'volume': 0.8,
      };

      final config = MetronomeToneConfig.fromJson(json);

      expect(config.mainRegularFreq, 1800.0);
      expect(config.mainAccentFreq, 2400.0);
      expect(config.subRegularFreq, 900.0);
      expect(config.subAccentFreq, 1200.0);
      expect(config.dividerRegularFreq, 1300.0);
      expect(config.dividerAccentFreq, 1700.0);
      expect(config.waveType, 'triangle');
      expect(config.volume, 0.8);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};
      final config = MetronomeToneConfig.fromJson(json);

      expect(config.mainRegularFreq, 1600.0); // Default
      expect(config.mainAccentFreq, 2060.0); // Default
      expect(config.waveType, 'sine'); // Default
      expect(config.volume, 0.75); // Default
    });

    // Test equality (Equatable)
    test('equality works correctly', () {
      final config1 = MetronomeToneConfig.classic();
      final config2 = MetronomeToneConfig.classic();
      final config3 = MetronomeToneConfig.extreme();

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    // Test availablePresets
    test('availablePresets returns correct list', () {
      final presets = MetronomeToneConfig.availablePresets;

      expect(presets.length, 5);
      expect(presets, contains('Classic'));
      expect(presets, contains('Subtle'));
      expect(presets, contains('Extreme'));
      expect(presets, contains('Wood Block'));
      expect(presets, contains('Electronic'));
    });
  });
}
