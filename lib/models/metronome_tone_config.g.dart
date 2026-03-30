// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metronome_tone_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MetronomeToneConfig _$MetronomeToneConfigFromJson(Map<String, dynamic> json) =>
    MetronomeToneConfig(
      mainRegularFreq: (json['mainRegularFreq'] as num?)?.toDouble() ?? 1600.0,
      mainAccentFreq: (json['mainAccentFreq'] as num?)?.toDouble() ?? 2060.0,
      subRegularFreq: (json['subRegularFreq'] as num?)?.toDouble() ?? 800.0,
      subAccentFreq: (json['subAccentFreq'] as num?)?.toDouble() ?? 1030.0,
      dividerRegularFreq:
          (json['dividerRegularFreq'] as num?)?.toDouble() ?? 1100.0,
      dividerAccentFreq:
          (json['dividerAccentFreq'] as num?)?.toDouble() ?? 1400.0,
      waveType: json['waveType'] as String? ?? 'sine',
      volume: (json['volume'] as num?)?.toDouble() ?? 0.75,
    );

Map<String, dynamic> _$MetronomeToneConfigToJson(
  MetronomeToneConfig instance,
) => <String, dynamic>{
  'mainRegularFreq': instance.mainRegularFreq,
  'mainAccentFreq': instance.mainAccentFreq,
  'subRegularFreq': instance.subRegularFreq,
  'subAccentFreq': instance.subAccentFreq,
  'dividerRegularFreq': instance.dividerRegularFreq,
  'dividerAccentFreq': instance.dividerAccentFreq,
  'waveType': instance.waveType,
  'volume': instance.volume,
};
