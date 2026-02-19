// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

class Setlist {
  final String id;
  final String bandId;
  final String name;
  final String? description;
  final String? eventDate;
  final String? eventLocation;
  final List<String> songIds;
  final int? totalDuration;
  final DateTime createdAt;
  final DateTime updatedAt;

  Setlist({
    required this.id,
    required this.bandId,
    required this.name,
    this.description,
    this.eventDate,
    this.eventLocation,
    this.songIds = const [],
    this.totalDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  Setlist copyWith({
    String? id,
    String? bandId,
    String? name,
    Object? description = _sentinel,
    Object? eventDate = _sentinel,
    Object? eventLocation = _sentinel,
    List<String>? songIds,
    Object? totalDuration = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Setlist(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      name: name ?? this.name,
      description: description == _sentinel
          ? this.description
          : description as String?,
      eventDate: eventDate == _sentinel ? this.eventDate : eventDate as String?,
      eventLocation: eventLocation == _sentinel
          ? this.eventLocation
          : eventLocation as String?,
      songIds: songIds ?? this.songIds,
      totalDuration: totalDuration == _sentinel
          ? this.totalDuration
          : totalDuration as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bandId': bandId,
    'name': name,
    'description': description,
    'eventDate': eventDate,
    'eventLocation': eventLocation,
    'songIds': songIds,
    'totalDuration': totalDuration,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Setlist.fromJson(Map<String, dynamic> json) => Setlist(
    id: json['id'] ?? '',
    bandId: json['bandId'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    eventDate: json['eventDate'],
    eventLocation: json['eventLocation'],
    songIds: (json['songIds'] as List<dynamic>?)?.cast<String>() ?? [],
    totalDuration: json['totalDuration'],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'])
        : DateTime.now(),
  );
}
