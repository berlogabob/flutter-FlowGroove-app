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
    String? description,
    String? eventDate,
    String? eventLocation,
    List<String>? songIds,
    int? totalDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Setlist(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      name: name ?? this.name,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      eventLocation: eventLocation ?? this.eventLocation,
      songIds: songIds ?? this.songIds,
      totalDuration: totalDuration ?? this.totalDuration,
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
