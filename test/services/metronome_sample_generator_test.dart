/// Unit tests for MetronomeSampleGenerator
///
/// Tests cover:
/// - Sample generation
/// - Sample caching
/// - Custom frequency samples
/// - Cache management
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/audio/metronome_sample_generator.dart';
import 'package:flowgroove/models/metronome_tone_config.dart';

void main() {
  group('MetronomeSampleGenerator', () {
    late MetronomeSampleGenerator generator;

    setUp(() {
      generator = MetronomeSampleGenerator();
    });

    tearDown(() {
      generator.clearCache();
    });

    // Test sample generation
    test('generates all 6 base samples', () async {
      final config = MetronomeToneConfig.classic();
      await generator.generateAllSamples(config);

      // Verify all samples are cached
      expect(generator.getSample('main_regular'), isNotNull);
      expect(generator.getSample('main_accent'), isNotNull);
      expect(generator.getSample('sub_regular'), isNotNull);
      expect(generator.getSample('sub_accent'), isNotNull);
      expect(generator.getSample('divider_regular'), isNotNull);
      expect(generator.getSample('divider_accent'), isNotNull);
    });

    test('generates samples with correct config', () async {
      final config = MetronomeToneConfig.extreme();
      await generator.generateAllSamples(config);

      // Verify samples are generated (not null)
      final mainRegular = generator.getSample('main_regular');
      expect(mainRegular, isNotNull);
      expect(mainRegular.length, greaterThan(0));
    });

    // Test sample caching
    test('caches samples on first generation', () async {
      final config = MetronomeToneConfig.classic();
      final initialCacheSize = generator.cacheSize;

      await generator.generateAllSamples(config);

      expect(generator.cacheSize, greaterThan(initialCacheSize));
    });

    test('returns cached sample on subsequent calls', () async {
      final config = MetronomeToneConfig.classic();
      await generator.generateAllSamples(config);

      final sample1 = generator.getSample('main_regular');
      final sample2 = generator.getSample('main_regular');

      expect(sample1, equals(sample2)); // Same cached sample
    });

    // Test custom frequency samples
    test('generates custom frequency sample', () async {
      final sample = await generator.getCustomSample(
        frequency: 1500.0,
        waveType: 'sine',
        volume: 0.75,
      );

      expect(sample, isNotNull);
      expect(sample.length, greaterThan(0));
    });

    test('caches custom frequency samples', () async {
      final initialCacheSize = generator.cacheSize;

      await generator.getCustomSample(
        frequency: 1500.0,
        waveType: 'sine',
        volume: 0.75,
      );

      expect(generator.cacheSize, greaterThan(initialCacheSize));
    });

    test('returns cached custom sample on subsequent calls', () async {
      final sample1 = await generator.getCustomSample(
        frequency: 1500.0,
        waveType: 'sine',
        volume: 0.75,
      );

      final sample2 = await generator.getCustomSample(
        frequency: 1500.0,
        waveType: 'sine',
        volume: 0.75,
      );

      expect(sample1, equals(sample2)); // Same cached sample
    });

    // Test cache management
    test('clearCache removes all samples', () async {
      final config = MetronomeToneConfig.classic();
      await generator.generateAllSamples(config);

      final cacheSizeBefore = generator.cacheSize;
      expect(cacheSizeBefore, greaterThan(0));

      generator.clearCache();

      expect(generator.cacheSize, equals(0));
    });

    test('cacheSize returns correct size', () async {
      expect(generator.cacheSize, equals(0));

      await generator.generateAllSamples(MetronomeToneConfig.classic());

      expect(generator.cacheSize, greaterThan(0));

      generator.clearCache();

      expect(generator.cacheSize, equals(0));
    });

    // Test different wave types
    test('generates samples for all wave types', () async {
      final waveTypes = ['sine', 'square', 'triangle', 'sawtooth'];

      for (final waveType in waveTypes) {
        final sample = await generator.getCustomSample(
          frequency: 1000.0,
          waveType: waveType,
          volume: 0.75,
        );

        expect(sample, isNotNull);
        expect(sample.length, greaterThan(0));
      }
    });

    // Test sample format (WAV)
    test('generates valid WAV format', () async {
      final sample = await generator.getCustomSample(
        frequency: 1000.0,
        waveType: 'sine',
        volume: 0.75,
      );

      // WAV header is 44 bytes
      expect(sample.length, greaterThan(44));

      // Check RIFF header
      expect(sample[0], 0x52); // 'R'
      expect(sample[1], 0x49); // 'I'
      expect(sample[2], 0x46); // 'F'
      expect(sample[3], 0x46); // 'F'

      // Check WAVE format
      expect(sample[8], 0x57); // 'W'
      expect(sample[9], 0x41); // 'A'
      expect(sample[10], 0x56); // 'V'
      expect(sample[11], 0x45); // 'E'
    });
  });
}
