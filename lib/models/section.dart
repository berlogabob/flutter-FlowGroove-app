import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import '../theme/mono_pulse_theme.dart';

part 'section.g.dart';

/// Model class representing a song section block.
///
/// Sections are used to build song structures like:
/// Intro → Verse → Chorus → Verse → Chorus → Bridge → Chorus → Outro
@collection
@JsonSerializable()
class Section {
  /// Unique identifier for this section.
  Id id = Isar.autoIncrement;

  /// The name/type of section (e.g., 'Intro', 'Verse', 'Chorus').
  @Index()
  String name = '';

  /// Optional notes for this section (e.g., chord progressions).
  String notes = '';

  /// Duration in phrases/bars.
  int duration = 1;

  /// Optional custom color (ARGB value).
  int? colorValue;

  Section({
    this.id = Isar.autoIncrement,
    required this.name,
    this.notes = '',
    this.duration = 1,
    this.colorValue,
  });

  /// Create from map for Isar compatibility.
  factory Section.fromMap(Map<String, dynamic> data) => Section(
    id: data['id'] as int? ?? Isar.autoIncrement,
    name: data['name'] as String? ?? '',
    notes: data['notes'] as String? ?? '',
    duration: data['duration'] as int? ?? 1,
    colorValue: data['colorValue'] as int?,
  );

  /// Convert to map for Isar compatibility.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'notes': notes,
    'duration': duration,
    'colorValue': colorValue,
  };

  Map<String, dynamic> toJson() => _$SectionToJson(this);
  factory Section.fromJson(Map<String, dynamic> json) => _$SectionFromJson(json);

  /// Equality operator based on unique ID.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Section && runtimeType == other.runtimeType && id == other.id;

  /// Hash code based on unique ID.
  @override
  int get hashCode => id.hashCode;

  /// Predefined template section names.
  static const List<String> templates = [
    'Intro',
    'Verse',
    'Chorus',
    'Bridge',
    'Pre-Chorus',
    'Outro',
    'Instrumental',
    'Solo',
    'Pause',
  ];

  /// Create a copy with updated fields.
  Section copyWith({
    String? name,
    String? notes,
    int? duration,
    int? colorValue,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      duration: duration ?? this.duration,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  /// Get color index for section (custom or hash-based default).
  int get colorIndex => colorValue != null ? 0 : name.hashCode.abs() % 14;

  /// Get the color for this section using MonoPulse theme colors.
  Color get color {
    if (colorValue != null) {
      return Color(colorValue!);
    }
    final index = colorIndex;
    return MonoPulseColors.sectionColors[index % MonoPulseColors.sectionColors.length];
  }

  /// Get contrasting text color for this section's background using MonoPulse theme.
  Color get contrastingTextColor {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? MonoPulseColors.black : MonoPulseColors.textPrimary;
  }
}
