import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

part 'song_arrangement.g.dart';

/// Type of arrangement/variant
enum ArrangementType {
  /// Original version
  original,

  /// Live performance
  live,

  /// Acoustic version
  acoustic,

  /// Remix
  remix,

  /// Cover version
  cover,

  /// Instrumental
  instrumental,

  /// Custom arrangement
  custom,
}

/// Song Arrangement - user/group-specific version of a canonical song
/// 
/// This represents a specific arrangement of a canonical song with:
/// - Performance key and tempo
/// - Custom structure
/// - User/group-specific modifications
/// 
/// Multiple arrangements can link to the same CanonicalSong,
/// allowing users to maintain their own versions while
/// preserving the canonical song identity.
@JsonSerializable()
class SongArrangement extends Equatable {
  /// Unique identifier
  final String id;

  /// ID of the canonical song this arrangement is based on
  final String canonicalSongId;

  /// Owner type (user or group)
  final String ownerType; // 'user' or 'group'

  /// Owner ID (user ID or band ID)
  final String ownerId;

  /// Band ID (if owner is group)
  final String? bandId;

  /// Arrangement type
  final ArrangementType arrangementType;

  /// Version name (e.g., "Live 2025", "Wedding Version")
  final String? versionName;

  /// Performance key (e.g., "C", "Gm", "A#")
  final String? key;

  /// Performance tempo in BPM
  final int? tempoBpm;

  /// Capo fret number (for guitar)
  final int? capoFret;

  /// Custom structure (JSON)
  final Map<String, dynamic>? structure;

  /// Performance notes
  final String? notes;

  /// Whether this arrangement is public (for groups)
  @JsonKey(defaultValue: false)
  final bool isPublic;

  /// ID of arrangement this was forked from (if any)
  final String? forkedFrom;

  /// When this arrangement was created
  final DateTime createdAt;

  /// When this arrangement was last updated
  final DateTime updatedAt;

  SongArrangement({
    required this.id,
    required this.canonicalSongId,
    required this.ownerType,
    required this.ownerId,
    this.bandId,
    this.arrangementType = ArrangementType.original,
    this.versionName,
    this.key,
    this.tempoBpm,
    this.capoFret,
    this.structure,
    this.notes,
    this.isPublic = false,
    this.forkedFrom,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create a personal arrangement.
  factory SongArrangement.personal({
    required String canonicalSongId,
    required String userId,
    String? key,
    int? tempoBpm,
    String? versionName,
  }) {
    return SongArrangement(
      id: const Uuid().v4(),
      canonicalSongId: canonicalSongId,
      ownerType: 'user',
      ownerId: userId,
      key: key,
      tempoBpm: tempoBpm,
      versionName: versionName ?? 'Personal Version',
    );
  }

  /// Create a group arrangement
  factory SongArrangement.group({
    required String canonicalSongId,
    required String bandId,
    String? key,
    int? tempoBpm,
    String? versionName,
    bool isPublic = true,
  }) {
    return SongArrangement(
      id: const Uuid().v4(),
      canonicalSongId: canonicalSongId,
      ownerType: 'group',
      ownerId: bandId,
      bandId: bandId,
      key: key,
      tempoBpm: tempoBpm,
      versionName: versionName ?? 'Band Version',
      isPublic: isPublic,
    );
  }

  /// Create a fork from existing arrangement
  factory SongArrangement.forkFrom({
    required SongArrangement parent,
    required String newOwnerId,
    String? newOwnerType,
  }) {
    return SongArrangement(
      id: const Uuid().v4(),
      canonicalSongId: parent.canonicalSongId,
      ownerType: newOwnerType ?? 'user',
      ownerId: newOwnerId,
      arrangementType: parent.arrangementType,
      versionName: '${parent.versionName} (My Version)',
      key: parent.key,
      tempoBpm: parent.tempoBpm,
      capoFret: parent.capoFret,
      structure: parent.structure,
      notes: parent.notes,
      forkedFrom: parent.id,
    );
  }

  factory SongArrangement.fromJson(Map<String, dynamic> json) =>
      _$SongArrangementFromJson(json);

  Map<String, dynamic> toJson() => _$SongArrangementToJson(this);

  SongArrangement copyWith({
    String? id,
    String? canonicalSongId,
    String? ownerType,
    String? ownerId,
    String? bandId,
    ArrangementType? arrangementType,
    String? versionName,
    String? key,
    int? tempoBpm,
    int? capoFret,
    Map<String, dynamic>? structure,
    String? notes,
    bool? isPublic,
    String? forkedFrom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SongArrangement(
      id: id ?? this.id,
      canonicalSongId: canonicalSongId ?? this.canonicalSongId,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      bandId: bandId ?? this.bandId,
      arrangementType: arrangementType ?? this.arrangementType,
      versionName: versionName ?? this.versionName,
      key: key ?? this.key,
      tempoBpm: tempoBpm ?? this.tempoBpm,
      capoFret: capoFret ?? this.capoFret,
      structure: structure ?? this.structure,
      notes: notes ?? this.notes,
      isPublic: isPublic ?? this.isPublic,
      forkedFrom: forkedFrom ?? this.forkedFrom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this is a group arrangement
  bool get isGroup => ownerType == 'group';

  /// Check if this is a personal arrangement
  bool get isPersonal => ownerType == 'user';

  /// Check if this arrangement is a fork
  bool get isFork => forkedFrom != null;

  /// Get display name
  String get displayName {
    if (versionName != null && versionName!.isNotEmpty) {
      return versionName!;
    }

    switch (arrangementType) {
      case ArrangementType.original:
        return 'Original Version';
      case ArrangementType.live:
        return 'Live Version';
      case ArrangementType.acoustic:
        return 'Acoustic Version';
      case ArrangementType.remix:
        return 'Remix';
      case ArrangementType.cover:
        return 'Cover Version';
      case ArrangementType.instrumental:
        return 'Instrumental';
      case ArrangementType.custom:
        return 'Custom Version';
    }
  }

  /// Get key and tempo display string
  String get keyAndTempoDisplay {
    final parts = <String>[];
    if (key != null) parts.add('Key: $key');
    if (tempoBpm != null) parts.add('$tempoBpm BPM');
    if (capoFret != null) parts.add('Capo: $capoFret');
    return parts.join(' • ');
  }

  @override
  List<Object?> get props => [
        id,
        canonicalSongId,
        ownerType,
        ownerId,
        arrangementType,
        key,
        tempoBpm,
        forkedFrom,
      ];
}
