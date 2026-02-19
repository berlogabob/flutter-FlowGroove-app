import 'link.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String? originalKey;
  final int? originalBPM;
  final String? ourKey;
  final int? ourBPM;
  final List<Link> links;
  final String? notes;
  final List<String> tags;
  final String? bandId;
  final String? spotifyUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.originalKey,
    this.originalBPM,
    this.ourKey,
    this.ourBPM,
    this.links = const [],
    this.notes,
    this.tags = const [],
    this.bandId,
    this.spotifyUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? originalKey,
    int? originalBPM,
    String? ourKey,
    int? ourBPM,
    List<Link>? links,
    String? notes,
    List<String>? tags,
    String? bandId,
    String? spotifyUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      originalKey: originalKey ?? this.originalKey,
      originalBPM: originalBPM ?? this.originalBPM,
      ourKey: ourKey ?? this.ourKey,
      ourBPM: ourBPM ?? this.ourBPM,
      links: links ?? this.links,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      bandId: bandId ?? this.bandId,
      spotifyUrl: spotifyUrl ?? this.spotifyUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'originalKey': originalKey,
    'originalBPM': originalBPM,
    'ourKey': ourKey,
    'ourBPM': ourBPM,
    'links': links.map((l) => l.toJson()).toList(),
    'notes': notes,
    'tags': tags,
    'bandId': bandId,
    'spotifyUrl': spotifyUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    artist: json['artist'] ?? '',
    originalKey: json['originalKey'],
    originalBPM: json['originalBPM'],
    ourKey: json['ourKey'],
    ourBPM: json['ourBPM'],
    links:
        (json['links'] as List<dynamic>?)
            ?.map((l) => Link.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [],
    notes: json['notes'],
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    bandId: json['bandId'],
    spotifyUrl: json['spotifyUrl'],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'])
        : DateTime.now(),
  );
}
