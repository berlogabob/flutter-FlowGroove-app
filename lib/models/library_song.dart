import 'song.dart';
import 'song_delta.dart';

/// Firestore document for a user/band library entry linked to a canonical song.
class LibrarySong {
  static const currentSchemaVersion = 2;

  final String id;
  final int schemaVersion;
  final String canonicalSongId;
  final String ownerType;
  final String ownerId;
  final int baseRevision;
  final SongDelta delta;
  final Song materialized;
  final String? latestCommitId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  LibrarySong({
    required this.id,
    this.schemaVersion = currentSchemaVersion,
    required this.canonicalSongId,
    required this.ownerType,
    required this.ownerId,
    this.baseRevision = 1,
    SongDelta? delta,
    required this.materialized,
    this.latestCommitId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : delta = delta ?? SongDelta(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory LibrarySong.fromJson(Map<String, dynamic> json) {
    return LibrarySong(
      id: json['id'] as String? ?? '',
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      canonicalSongId: json['canonicalSongId'] as String? ?? '',
      ownerType: json['ownerType'] as String? ?? 'user',
      ownerId: json['ownerId'] as String? ?? '',
      baseRevision: (json['baseRevision'] as num?)?.toInt() ?? 1,
      delta: SongDelta.fromJson(
        Map<String, dynamic>.from(json['delta'] as Map? ?? const {}),
      ),
      materialized: Song.fromJson(
        Map<String, dynamic>.from(json['materialized'] as Map? ?? const {}),
      ),
      latestCommitId: json['latestCommitId'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      deletedAt: _parseNullableDateTime(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schemaVersion': schemaVersion,
      'canonicalSongId': canonicalSongId,
      'ownerType': ownerType,
      'ownerId': ownerId,
      'baseRevision': baseRevision,
      'delta': delta.toJson(),
      'materialized': materialized.toJson(),
      'latestCommitId': latestCommitId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  bool get isDeleted => deletedAt != null;
}

DateTime _parseDateTime(dynamic value) {
  return _parseNullableDateTime(value) ?? DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }
  } catch (_) {}
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}
