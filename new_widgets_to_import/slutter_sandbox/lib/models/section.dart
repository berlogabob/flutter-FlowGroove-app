/// Model class representing a song section block.
class Section {
  final String id;
  String name;
  String notes;
  int duration;
  int? colorValue; // Optional custom color (ARGB value)

  Section({
    required this.id,
    required this.name,
    this.notes = '',
    this.duration = 1,
    this.colorValue,
  });

  /// Predefined template section names
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

  /// Create a copy with updated fields
  Section copyWith({String? name, String? notes, int? duration, int? colorValue}) {
    return Section(
      id: id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      duration: duration ?? this.duration,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'duration': duration,
      if (colorValue != null) 'colorValue': colorValue,
    };
  }

  /// Create from JSON map
  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String? ?? '',
      duration: json['duration'] as int? ?? 1,
      colorValue: json['colorValue'] as int?,
    );
  }

  /// Get color for section (custom or hash-based default)
  int get colorIndex => name.hashCode.abs() % 17;
}
