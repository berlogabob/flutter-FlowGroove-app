import 'song_delta.dart';

/// Linear history entry for a linked library song.
class SongCommit {
  SongCommit({
    required this.id,
    required this.canonicalSongId,
    required this.operation,
    required this.authorId,
    required this.clientMutationId,
    this.parentCommitId,
    this.baseRevision = 1,
    SongDelta? delta,
    this.message,
    DateTime? createdAt,
  }) : delta = delta ?? SongDelta(),
       createdAt = createdAt ?? DateTime.now();

  factory SongCommit.fromJson(Map<String, dynamic> json) {
    return SongCommit(
      id: json['id'] as String? ?? '',
      parentCommitId: json['parentCommitId'] as String?,
      canonicalSongId: json['canonicalSongId'] as String? ?? '',
      baseRevision: (json['baseRevision'] as num?)?.toInt() ?? 1,
      delta: SongDelta.fromJson(
        Map<String, dynamic>.from(json['delta'] as Map? ?? const {}),
      ),
      operation: json['operation'] as String? ?? 'update',
      authorId: json['authorId'] as String? ?? '',
      message: json['message'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      clientMutationId: json['clientMutationId'] as String? ?? '',
    );
  }

  final String id;
  final String? parentCommitId;
  final String canonicalSongId;
  final int baseRevision;
  final SongDelta delta;
  final String operation;
  final String authorId;
  final String? message;
  final DateTime createdAt;
  final String clientMutationId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentCommitId': parentCommitId,
      'canonicalSongId': canonicalSongId,
      'baseRevision': baseRevision,
      'delta': delta.toJson(),
      'operation': operation,
      'authorId': authorId,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'clientMutationId': clientMutationId,
    };
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  try {
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }
  } catch (_) {}
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}
