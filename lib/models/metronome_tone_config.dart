import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

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
  const factory MetronomeToneConfig.classic() => MetronomeToneConfig(
        mainRegularFreq: 1600.0,
        mainAccentFreq: 2060.0,
        subRegularFreq: 800.0,
        subAccentFreq: 1030.0,
        dividerRegularFreq: 1100.0,
        dividerAccentFreq: 1400.0,
        waveType: 'sine',
        volume: 0.75,
      );

  /// Subtle preset - Soft, gentle clicks
  const factory MetronomeToneConfig.subtle() => MetronomeToneConfig(
        mainRegularFreq: 1200.0,
        mainAccentFreq: 1600.0,
        subRegularFreq: 600.0,
        subAccentFreq: 800.0,
        dividerRegularFreq: 900.0,
        dividerAccentFreq: 1200.0,
        waveType: 'sine',
        volume: 0.5,
      );

  /// Extreme preset - Loud, distinct clicks
  const factory MetronomeToneConfig.extreme() => MetronomeToneConfig(
        mainRegularFreq: 2000.0,
        mainAccentFreq: 2800.0,
        subRegularFreq: 1000.0,
        subAccentFreq: 1400.0,
        dividerRegularFreq: 1500.0,
        dividerAccentFreq: 2000.0,
        waveType: 'square',
        volume: 1.0,
      );

  /// Wood block preset - Simulates wood block sound
  const factory MetronomeToneConfig.woodBlock() => MetronomeToneConfig(
        mainRegularFreq: 1800.0,
        mainAccentFreq: 2400.0,
        subRegularFreq: 900.0,
        subAccentFreq: 1200.0,
        dividerRegularFreq: 1300.0,
        dividerAccentFreq: 1700.0,
        waveType: 'triangle',
        volume: 0.8,
      );

  /// Electronic preset - Digital/electronic sound
  const factory MetronomeToneConfig.electronic() => MetronomeToneConfig(
        mainRegularFreq: 2200.0,
        mainAccentFreq: 3000.0,
        subRegularFreq: 1100.0,
        subAccentFreq: 1500.0,
        dividerRegularFreq: 1600.0,
        dividerAccentFreq: 2200.0,
        waveType: 'sawtooth',
        volume: 0.9,
      );

  factory MetronomeToneConfig.fromJson(Map<String, dynamic> json) => MetronomeToneConfig(
        mainRegularFreq: (json['mainRegularFreq'] as num?)?.toDouble() ?? 1600.0,
        mainAccentFreq: (json['mainAccentFreq'] as num?)?.toDouble() ?? 2060.0,
        subRegularFreq: (json['subRegularFreq'] as num?)?.toDouble() ?? 800.0,
        subAccentFreq: (json['subAccentFreq'] as num?)?.toDouble() ?? 1030.0,
        dividerRegularFreq: (json['dividerRegularFreq'] as num?)?.toDouble() ?? 1100.0,
        dividerAccentFreq: (json['dividerAccentFreq'] as num?)?.toDouble() ?? 1400.0,
        waveType: json['waveType'] as String? ?? 'sine',
        volume: (json['volume'] as num?)?.toDouble() ?? 0.75,
      );

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
          mainRegularFreq: 1600.0,
          mainAccentFreq: 2060.0,
          subRegularFreq: 800.0,
          subAccentFreq: 1030.0,
          dividerRegularFreq: 1100.0,
          dividerAccentFreq: 1400.0,
          waveType: 'sine',
          volume: 0.75,
        );
      case 'subtle':
        return const MetronomeToneConfig(
          mainRegularFreq: 1200.0,
          mainAccentFreq: 1600.0,
          subRegularFreq: 600.0,
          subAccentFreq: 800.0,
          dividerRegularFreq: 900.0,
          dividerAccentFreq: 1200.0,
          waveType: 'sine',
          volume: 0.5,
        );
      case 'extreme':
        return const MetronomeToneConfig(
          mainRegularFreq: 2000.0,
          mainAccentFreq: 2800.0,
          subRegularFreq: 1000.0,
          subAccentFreq: 1400.0,
          dividerRegularFreq: 1500.0,
          dividerAccentFreq: 2000.0,
          waveType: 'square',
          volume: 1.0,
        );
      case 'wood block':
      case 'woodblock':
        return const MetronomeToneConfig(
          mainRegularFreq: 1800.0,
          mainAccentFreq: 2400.0,
          subRegularFreq: 900.0,
          subAccentFreq: 1200.0,
          dividerRegularFreq: 1300.0,
          dividerAccentFreq: 1700.0,
          waveType: 'triangle',
          volume: 0.8,
        );
      case 'electronic':
        return const MetronomeToneConfig(
          mainRegularFreq: 2200.0,
          mainAccentFreq: 3000.0,
          subRegularFreq: 1100.0,
          subAccentFreq: 1500.0,
          dividerRegularFreq: 1600.0,
          dividerAccentFreq: 2200.0,
          waveType: 'sawtooth',
          volume: 0.9,
        );
      default:
        return const MetronomeToneConfig(
          mainRegularFreq: 1600.0,
          mainAccentFreq: 2060.0,
          subRegularFreq: 800.0,
          subAccentFreq: 1030.0,
          dividerRegularFreq: 1100.0,
          dividerAccentFreq: 1400.0,
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
      mainRegularFreq >= 200.0 &&
      mainRegularFreq <= 4000.0 &&
      mainAccentFreq >= 200.0 &&
      mainAccentFreq <= 4000.0 &&
      subRegularFreq >= 200.0 &&
      subRegularFreq <= 4000.0 &&
      subAccentFreq >= 200.0 &&
      subAccentFreq <= 4000.0 &&
      dividerRegularFreq >= 200.0 &&
      dividerRegularFreq <= 4000.0 &&
      dividerAccentFreq >= 200.0 &&
      dividerAccentFreq <= 4000.0 &&
      volume >= 0.0 &&
      volume <= 1.0 &&
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
