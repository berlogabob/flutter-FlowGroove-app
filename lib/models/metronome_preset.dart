import 'package:flutter/material.dart';
import '../models/time_signature.dart';

/// Preset for metronome settings
class MetronomePreset {
  final String id;
  final String name;
  final int bpm;
  final TimeSignature timeSignature;
  final String waveType;
  final bool accentEnabled;
  final DateTime createdAt;

  const MetronomePreset({
    required this.id,
    required this.name,
    required this.bpm,
    required this.timeSignature,
    required this.waveType,
    required this.accentEnabled,
    required this.createdAt,
  });

  /// Create preset from JSON
  factory MetronomePreset.fromJson(Map<String, dynamic> json) {
    return MetronomePreset(
      id: json['id'] as String,
      name: json['name'] as String,
      bpm: json['bpm'] as int,
      timeSignature: TimeSignature(
        numerator: json['numerator'] as int,
        denominator: json['denominator'] as int,
      ),
      waveType: json['waveType'] as String,
      accentEnabled: json['accentEnabled'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert preset to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bpm': bpm,
      'numerator': timeSignature.numerator,
      'denominator': timeSignature.denominator,
      'waveType': waveType,
      'accentEnabled': accentEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  MetronomePreset copyWith({
    String? id,
    String? name,
    int? bpm,
    TimeSignature? timeSignature,
    String? waveType,
    bool? accentEnabled,
    DateTime? createdAt,
  }) {
    return MetronomePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      waveType: waveType ?? this.waveType,
      accentEnabled: accentEnabled ?? this.accentEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Display name with BPM and time signature
  String get displayName => '$name ($bpm BPM ${timeSignature.displayName})';

  /// Common presets
  static const List<MetronomePreset> defaults = [
    MetronomePreset(
      id: 'default_1',
      name: 'Slow Practice',
      bpm: 60,
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
      waveType: 'sine',
      accentEnabled: true,
      createdAt: DateTime(2026),
    ),
    MetronomePreset(
      id: 'default_2',
      name: 'Medium Rock',
      bpm: 120,
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
      waveType: 'square',
      accentEnabled: true,
      createdAt: DateTime(2026),
    ),
    MetronomePreset(
      id: 'default_3',
      name: 'Waltz',
      bpm: 90,
      timeSignature: TimeSignature(numerator: 3, denominator: 4),
      waveType: 'sine',
      accentEnabled: true,
      createdAt: DateTime(2026),
    ),
  ];
}
