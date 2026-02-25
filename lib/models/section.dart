import 'package:flutter/material.dart';

/// Model class representing a song section block.
///
/// Sections are used to build song structures like:
/// Intro → Verse → Chorus → Verse → Chorus → Bridge → Chorus → Outro
class Section {
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

  Section({
    required this.id,
    required this.name,
    this.notes = '',
    this.duration = 1,
    this.colorValue,
  });

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

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'duration': duration,
      if (colorValue != null) 'colorValue': colorValue,
    };
  }

  /// Create from JSON map.
  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String? ?? '',
      duration: json['duration'] as int? ?? 1,
      colorValue: json['colorValue'] as int?,
    );
  }

  /// Get color index for section (custom or hash-based default).
  int get colorIndex => colorValue != null ? 0 : name.hashCode.abs() % 17;

  /// Get the color for this section.
  Color get color {
    if (colorValue != null) {
      return Color(colorValue!);
    }
    final index = colorIndex;
    return _getDefaultColorAt(index);
  }

  /// Get default color from palette at index.
  Color _getDefaultColorAt(int index) {
    const colors = [
      Color(0xFF42A5F5), // Blue
      Color(0xFF66BB6A), // Green
      Color(0xFFEF5350), // Red
      Color(0xFFFFA726), // Orange
      Color(0xFFAB47BC), // Purple
      Color(0xFF26A69A), // Teal
      Color(0xFF5C6BC0), // Indigo
      Color(0xFFEC407A), // Pink
      Color(0xFF26C6DA), // Cyan
      Color(0xFF9CCC65), // Lime
      Color(0xFFFFCA28), // Amber
      Color(0xFF8D6E63), // Brown
      Color(0xFFBDBDBD), // Grey
      Color(0xFF78909C), // Blue Grey
      Color(0xFFD4E157), // Light Green
      Color(0xFF7E57C2), // Deep Purple
      Color(0xFFFF7043), // Deep Orange
    ];
    return colors[index % colors.length];
  }

  /// Get contrasting text color for this section's background.
  Color get contrastingTextColor {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
