import 'link.dart';

// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

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

  // NEW: Sharing fields for copying songs from personal banks to band banks
  final String? originalOwnerId; // User who created original song
  final String? contributedBy; // User who added to band
  final bool isCopy; // True if this is a band's copy
  final DateTime? contributedAt; // When added to band

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
    this.originalOwnerId,
    this.contributedBy,
    this.isCopy = false,
    this.contributedAt,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    Object? originalKey = _sentinel,
    Object? originalBPM = _sentinel,
    Object? ourKey = _sentinel,
    Object? ourBPM = _sentinel,
    List<Link>? links,
    Object? notes = _sentinel,
    List<String>? tags,
    Object? bandId = _sentinel,
    Object? spotifyUrl = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? originalOwnerId = _sentinel,
    Object? contributedBy = _sentinel,
    Object? isCopy = _sentinel,
    Object? contributedAt = _sentinel,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      originalKey: originalKey == _sentinel
          ? this.originalKey
          : originalKey as String?,
      originalBPM: originalBPM == _sentinel
          ? this.originalBPM
          : originalBPM as int?,
      ourKey: ourKey == _sentinel ? this.ourKey : ourKey as String?,
      ourBPM: ourBPM == _sentinel ? this.ourBPM : ourBPM as int?,
      links: links ?? this.links,
      notes: notes == _sentinel ? this.notes : notes as String?,
      tags: tags ?? this.tags,
      bandId: bandId == _sentinel ? this.bandId : bandId as String?,
      spotifyUrl: spotifyUrl == _sentinel
          ? this.spotifyUrl
          : spotifyUrl as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originalOwnerId: originalOwnerId == _sentinel
          ? this.originalOwnerId
          : originalOwnerId as String?,
      contributedBy: contributedBy == _sentinel
          ? this.contributedBy
          : contributedBy as String?,
      isCopy: isCopy == _sentinel ? this.isCopy : isCopy as bool,
      contributedAt: contributedAt == _sentinel
          ? this.contributedAt
          : contributedAt as DateTime?,
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
    // Sharing fields
    'originalOwnerId': originalOwnerId,
    'contributedBy': contributedBy,
    'isCopy': isCopy,
    'contributedAt': contributedAt?.toIso8601String(),
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
    // Sharing fields (nullable for backward compatibility)
    originalOwnerId: json['originalOwnerId'],
    contributedBy: json['contributedBy'],
    isCopy: json['isCopy'] ?? false,
    contributedAt: json['contributedAt'] != null
        ? DateTime.parse(json['contributedAt'])
        : null,
  );
}
