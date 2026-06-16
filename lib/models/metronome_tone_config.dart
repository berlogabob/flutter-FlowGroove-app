import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

// Manual JSON serialization (more reliable than generated)
// part 'metronome_tone_config.g.dart';

/// Metronome tone configuration
///
/// Allows users to customize the sound of metronome clicks by adjusting
/// frequencies for different beat types and accent states.
///
/// Professional-grade customization matching industry standards:
/// - 6 independent frequency controls (3 beat types × 2 accent states)
/// - 4 wave types (sine, square, triangle, sawtooth)
/// - Volume control (0.0-1.0)
/// - 5 professional presets
@JsonSerializable()
class MetronomeToneConfig extends Equatable {
  const MetronomeToneConfig({
    required this.mainRegularFreq,
    required this.mainAccentFreq,
    required this.subRegularFreq,
    required this.subAccentFreq,
    required this.dividerRegularFreq,
    required this.dividerAccentFreq,
    required this.waveType,
    required this.volume,
  });

  /// Classic preset - Traditional metronome sound
  factory MetronomeToneConfig.classic() => const MetronomeToneConfig(
        mainRegularFreq: 1600,
        mainAccentFreq: 2060,
        subRegularFreq: 800,
        subAccentFreq: 1030,
        dividerRegularFreq: 1100,
        dividerAccentFreq: 1400,
        waveType: 'sine',
        volume: 0.75,
      );

  /// Subtle preset - Soft, gentle clicks
  factory MetronomeToneConfig.subtle() => const MetronomeToneConfig(
        mainRegularFreq: 1200,
        mainAccentFreq: 1600,
        subRegularFreq: 600,
        subAccentFreq: 800,
        dividerRegularFreq: 900,
        dividerAccentFreq: 1200,
        waveType: 'sine',
        volume: 0.5,
      );

  /// Extreme preset - Loud, distinct clicks
  factory MetronomeToneConfig.extreme() => const MetronomeToneConfig(
        mainRegularFreq: 2000,
        mainAccentFreq: 2800,
        subRegularFreq: 1000,
        subAccentFreq: 1400,
        dividerRegularFreq: 1500,
        dividerAccentFreq: 2000,
        waveType: 'square',
        volume: 1,
      );

  /// Wood block preset - Simulates wood block sound
  factory MetronomeToneConfig.woodBlock() => const MetronomeToneConfig(
        mainRegularFreq: 1800,
        mainAccentFreq: 2400,
        subRegularFreq: 900,
        subAccentFreq: 1200,
        dividerRegularFreq: 1300,
        dividerAccentFreq: 1700,
        waveType: 'triangle',
        volume: 0.8,
      );

  /// Electronic preset - Digital/electronic sound
  factory MetronomeToneConfig.electronic() => const MetronomeToneConfig(
        mainRegularFreq: 2200,
        mainAccentFreq: 3000,
        subRegularFreq: 1100,
        subAccentFreq: 1500,
        dividerRegularFreq: 1600,
        dividerAccentFreq: 2200,
        waveType: 'sawtooth',
        volume: 0.9,
      );

  factory MetronomeToneConfig.fromJson(Map<String, dynamic> json) => MetronomeToneConfig(
        mainRegularFreq: (json['mainRegularFreq'] as num?)?.toDouble() ?? 1600,
        mainAccentFreq: (json['mainAccentFreq'] as num?)?.toDouble() ?? 2060,
        subRegularFreq: (json['subRegularFreq'] as num?)?.toDouble() ?? 800,
        subAccentFreq: (json['subAccentFreq'] as num?)?.toDouble() ?? 1030,
        dividerRegularFreq: (json['dividerRegularFreq'] as num?)?.toDouble() ?? 1100,
        dividerAccentFreq: (json['dividerAccentFreq'] as num?)?.toDouble() ?? 1400,
        waveType: json['waveType'] as String? ?? 'sine',
        volume: (json['volume'] as num?)?.toDouble() ?? 0.75,
      );

  /// Main beat frequencies (first beat of measure)
  @JsonKey(defaultValue: 1600.0)
  final double mainRegularFreq;

  @JsonKey(defaultValue: 2060.0)
  final double mainAccentFreq;

  /// Sub beat frequencies (subdivisions)
  @JsonKey(defaultValue: 800.0)
  final double subRegularFreq;

  @JsonKey(defaultValue: 1030.0)
  final double subAccentFreq;

  /// Divider frequencies (fine subdivisions)
  @JsonKey(defaultValue: 1100.0)
  final double dividerRegularFreq;

  @JsonKey(defaultValue: 1400.0)
  final double dividerAccentFreq;

  /// Wave type for sound synthesis
  @JsonKey(defaultValue: 'sine')
  final String waveType;

  /// Master volume (0.0-1.0)
  @JsonKey(defaultValue: 0.75)
  final double volume;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mainRegularFreq': mainRegularFreq,
        'mainAccentFreq': mainAccentFreq,
        'subRegularFreq': subRegularFreq,
        'subAccentFreq': subAccentFreq,
        'dividerRegularFreq': dividerRegularFreq,
        'dividerAccentFreq': dividerAccentFreq,
        'waveType': waveType,
        'volume': volume,
      };

  MetronomeToneConfig copyWith({
    double? mainRegularFreq,
    double? mainAccentFreq,
    double? subRegularFreq,
    double? subAccentFreq,
    double? dividerRegularFreq,
    double? dividerAccentFreq,
    String? waveType,
    double? volume,
  }) {
    return MetronomeToneConfig(
      mainRegularFreq: mainRegularFreq ?? this.mainRegularFreq,
      mainAccentFreq: mainAccentFreq ?? this.mainAccentFreq,
      subRegularFreq: subRegularFreq ?? this.subRegularFreq,
      subAccentFreq: subAccentFreq ?? this.subAccentFreq,
      dividerRegularFreq: dividerRegularFreq ?? this.dividerRegularFreq,
      dividerAccentFreq: dividerAccentFreq ?? this.dividerAccentFreq,
      waveType: waveType ?? this.waveType,
      volume: volume ?? this.volume,
    );
  }

  /// Get preset by name
  static MetronomeToneConfig fromPresetName(String name) {
    switch (name.toLowerCase()) {
      case 'classic':
        return const MetronomeToneConfig(
          mainRegularFreq: 1600,
          mainAccentFreq: 2060,
          subRegularFreq: 800,
          subAccentFreq: 1030,
          dividerRegularFreq: 1100,
          dividerAccentFreq: 1400,
          waveType: 'sine',
          volume: 0.75,
        );
      case 'subtle':
        return const MetronomeToneConfig(
          mainRegularFreq: 1200,
          mainAccentFreq: 1600,
          subRegularFreq: 600,
          subAccentFreq: 800,
          dividerRegularFreq: 900,
          dividerAccentFreq: 1200,
          waveType: 'sine',
          volume: 0.5,
        );
      case 'extreme':
        return const MetronomeToneConfig(
          mainRegularFreq: 2000,
          mainAccentFreq: 2800,
          subRegularFreq: 1000,
          subAccentFreq: 1400,
          dividerRegularFreq: 1500,
          dividerAccentFreq: 2000,
          waveType: 'square',
          volume: 1,
        );
      case 'wood block':
      case 'woodblock':
        return const MetronomeToneConfig(
          mainRegularFreq: 1800,
          mainAccentFreq: 2400,
          subRegularFreq: 900,
          subAccentFreq: 1200,
          dividerRegularFreq: 1300,
          dividerAccentFreq: 1700,
          waveType: 'triangle',
          volume: 0.8,
        );
      case 'electronic':
        return const MetronomeToneConfig(
          mainRegularFreq: 2200,
          mainAccentFreq: 3000,
          subRegularFreq: 1100,
          subAccentFreq: 1500,
          dividerRegularFreq: 1600,
          dividerAccentFreq: 2200,
          waveType: 'sawtooth',
          volume: 0.9,
        );
      default:
        return const MetronomeToneConfig(
          mainRegularFreq: 1600,
          mainAccentFreq: 2060,
          subRegularFreq: 800,
          subAccentFreq: 1030,
          dividerRegularFreq: 1100,
          dividerAccentFreq: 1400,
          waveType: 'sine',
          volume: 0.75,
        );
    }
  }

  /// Get frequency for a given beat type and accent state
  double getFrequency({
    required bool isMainBeat,
    required bool isSubdivision,
    required bool isAccented,
  }) {
    if (isMainBeat) {
      return isAccented ? mainAccentFreq : mainRegularFreq;
    } else if (isSubdivision) {
      return isAccented ? subAccentFreq : subRegularFreq;
    } else {
      return isAccented ? dividerAccentFreq : dividerRegularFreq;
    }
  }

  /// Validate configuration values
  bool get isValid =>
      mainRegularFreq >= 200 &&
      mainRegularFreq <= 4000 &&
      mainAccentFreq >= 200 &&
      mainAccentFreq <= 4000 &&
      subRegularFreq >= 200 &&
      subRegularFreq <= 4000 &&
      subAccentFreq >= 200 &&
      subAccentFreq <= 4000 &&
      dividerRegularFreq >= 200 &&
      dividerRegularFreq <= 4000 &&
      dividerAccentFreq >= 200 &&
      dividerAccentFreq <= 4000 &&
      volume >= 0 &&
      volume <= 1 &&
      ['sine', 'square', 'triangle', 'sawtooth'].contains(waveType);

  /// Get all available presets
  static List<String> get availablePresets => [
        'Classic',
        'Subtle',
        'Extreme',
        'Wood Block',
        'Electronic',
      ];

  @override
  List<Object?> get props => [
        mainRegularFreq,
        mainAccentFreq,
        subRegularFreq,
        subAccentFreq,
        dividerRegularFreq,
        dividerAccentFreq,
        waveType,
        volume,
      ];
}
