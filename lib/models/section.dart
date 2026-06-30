import 'package:flutter/material.dart';
import '../theme/mono_pulse_theme.dart';

/// Model class representing a song section block.
///
/// Sections are used to build song structures like:
/// Intro → Verse → Chorus → Verse → Chorus → Bridge → Chorus → Outro
class Section {

  Section({
    required this.id,
    required this.name,
    this.notes = '',
    this.duration = 1,
    this.colorValue,
    this.chordChart,
  });

  /// Create from JSON map.
  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String? ?? '',
      duration: json['duration'] as int? ?? 1,
      colorValue: json['colorValue'] as int?,
      chordChart: json['chordChart'] as String?,
    );
  }
  /// Unique identifier for this section.
  final String id;

  /// The name/type of section (e.g., 'Intro', 'Verse', 'Chorus').
  String name;

  /// Optional notes for this section (e.g., chord progressions).
  String notes;

  /// Duration in phrases/bars.
  int duration;

  /// Optional custom color (ARGB value).
  int? colorValue;

  /// Optional lyrics with inline chords in ChordPro format, e.g.
  /// `[Am]Twinkle [F]little [C]star`. One parser ([parseChordProLine]) renders
  /// this as chords-over-lyrics and powers transpose/export.
  String? chordChart;

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
    String? chordChart,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      duration: duration ?? this.duration,
      colorValue: colorValue ?? this.colorValue,
      chordChart: chordChart ?? this.chordChart,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'duration': duration,
      if (colorValue != null) 'colorValue': colorValue,
      if (chordChart != null && chordChart!.isNotEmpty) 'chordChart': chordChart,
    };
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
