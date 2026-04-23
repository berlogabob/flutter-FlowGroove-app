/// Instrument and Tuning models for the tuner instrument library.
///
/// These models represent the static data loaded from assets/data/tunings.json.

/// A single tuning configuration for an instrument.
class Tuning {
  /// Unique identifier for this tuning within its instrument.
  final String id;

  /// Display name (e.g., "Standard", "Drop D").
  final String name;

  /// Note names for each string (e.g., ["E2", "A2", "D3", "G3", "B3", "E4"]).
  final List<String> notes;

  const Tuning({
    required this.id,
    required this.name,
    required this.notes,
  });

  /// Number of strings in this tuning.
  int get stringCount => notes.length;

  /// Create from JSON map.
  factory Tuning.fromJson(Map<String, dynamic> json) {
    return Tuning(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: (json['notes'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
    };
  }

  @override
  String toString() => 'Tuning($id: $name, ${notes.length} strings)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tuning && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}

/// An instrument with multiple tunings.
class Instrument {
  /// Unique identifier (e.g., "guitar_6", "cavaquinho").
  final String id;

  /// Display name (e.g., "Guitar", "Cavaquinho").
  final String name;

  /// Subtitle or region (e.g., "6-String", "Brazil").
  final String subtitle;

  /// Origin region for display.
  final String origin;

  /// Material icon name for this instrument.
  final String icon;

  /// Number of strings.
  final int stringCount;

  /// Labels for each string (e.g., ["6", "5", "4", "3", "2", "1"]).
  final List<String> stringLabels;

  /// Available tunings for this instrument.
  final List<Tuning> tunings;

  const Instrument({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.origin,
    required this.icon,
    required this.stringCount,
    required this.stringLabels,
    required this.tunings,
  });

  /// Get the default (first) tuning.
  Tuning get defaultTuning => tunings.first;

  /// Create from JSON map.
  factory Instrument.fromJson(Map<String, dynamic> json) {
    return Instrument(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String,
      origin: json['origin'] as String,
      icon: json['icon'] as String,
      stringCount: json['stringCount'] as int,
      stringLabels: (json['stringLabels'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      tunings: (json['tunings'] as List<dynamic>)
          .map((t) => Tuning.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'origin': origin,
      'icon': icon,
      'stringCount': stringCount,
      'stringLabels': stringLabels,
      'tunings': tunings.map((t) => t.toJson()).toList(),
    };
  }

  @override
  String toString() => 'Instrument($id: $name, ${tunings.length} tunings)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Instrument && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Detection mode for the Listen & Tune mode.
enum DetectionMode {
  /// Automatically detect whatever note is being played.
  auto,

  /// User selects a specific string/note to listen for.
  manual,
}
