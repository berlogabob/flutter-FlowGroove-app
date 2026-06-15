import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'musicbrainz_recording.g.dart';

/// Artist credit in MusicBrainz response
@JsonSerializable()
class MusicBrainzArtistCredit extends Equatable {
  final MusicBrainzArtist artist;
  final String? name;
  final String? joinPhrase;

  const MusicBrainzArtistCredit({
    required this.artist,
    this.name,
    this.joinPhrase,
  });

  factory MusicBrainzArtistCredit.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzArtistCreditFromJson(json);

  Map<String, dynamic> toJson() => _$MusicBrainzArtistCreditToJson(this);

  @override
  List<Object?> get props => [artist.id, name, joinPhrase];

  String get displayName => name ?? artist.name;
}

/// Artist in MusicBrainz response
@JsonSerializable()
class MusicBrainzArtist extends Equatable {
  final String id;
  final String name;
  final String? disambiguation;
  final String? sortName;

  const MusicBrainzArtist({
    required this.id,
    required this.name,
    this.disambiguation,
    this.sortName,
  });

  factory MusicBrainzArtist.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzArtistFromJson(json);

  Map<String, dynamic> toJson() => _$MusicBrainzArtistToJson(this);

  @override
  List<Object?> get props => [id, name, disambiguation];

  String get displayString {
    if (disambiguation != null && disambiguation!.isNotEmpty) {
      return '$name ($disambiguation)';
    }
    return name;
  }
}

/// Release (album/single) in MusicBrainz response
@JsonSerializable()
class MusicBrainzRelease extends Equatable {
  final String id;
  final String title;
  final String? date;
  final String? country;
  final List<String>? media;

  const MusicBrainzRelease({
    required this.id,
    required this.title,
    this.date,
    this.country,
    this.media,
  });

  factory MusicBrainzRelease.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$MusicBrainzReleaseToJson(this);

  @override
  List<Object?> get props => [id, title, date];

  int? get releaseYear {
    if (date == null) return null;
    final yearStr = date!.split('-').first;
    return int.tryParse(yearStr);
  }
}

/// MusicBrainz Recording - represents a specific audio recording
/// 
/// This is the main model for MusicBrainz API responses.
/// A Recording can appear on multiple releases and have multiple artists.
/// 
/// See: https://musicbrainz.org/doc/Recording
@JsonSerializable()
class MusicBrainzRecording extends Equatable {
  /// MusicBrainz ID (UUID)
  final String id;

  /// Recording title
  final String title;

  /// Artist credits (who performed this recording)
  @JsonKey(name: 'artist-credit', defaultValue: [])
  final List<MusicBrainzArtistCredit> artistCredit;

  /// Disambiguation (e.g., "live", "radio edit")
  final String? disambiguation;

  /// Duration in milliseconds
  @JsonKey(name: 'length')
  final int? lengthMs;

  /// ISRC codes (International Standard Recording Code)
  @JsonKey(defaultValue: [])
  final List<String> isrcs;

  /// Releases this recording appears on
  @JsonKey(defaultValue: [])
  final List<MusicBrainzRelease> releases;

  /// Aliases (alternative titles)
  @JsonKey(defaultValue: [])
  final List<MusicBrainzAlias> aliases;

  const MusicBrainzRecording({
    required this.id,
    required this.title,
    this.artistCredit = const [],
    this.disambiguation,
    this.lengthMs,
    this.isrcs = const [],
    this.releases = const [],
    this.aliases = const [],
  });

  factory MusicBrainzRecording.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzRecordingFromJson(json);

  Map<String, dynamic> toJson() => _$MusicBrainzRecordingToJson(this);

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        disambiguation,
        lengthMs,
        isrcs,
      ];

  /// Get primary artist name from artist-credit
  String get artist {
    if (artistCredit.isEmpty) return 'Unknown';
    return artistCredit.map((ac) => ac.displayName).join(', ');
  }

  /// Get all artist names as list
  List<String> get artists =>
      artistCredit.map((ac) => ac.displayName).toList();

  /// Get first release year
  int? get releaseYear {
    if (releases.isEmpty) return null;
    return releases.first.releaseYear;
  }

  /// Get first release title
  String? get album {
    if (releases.isEmpty) return null;
    return releases.first.title;
  }

  /// Get first ISRC code
  String? get isrc => isrcs.isNotEmpty ? isrcs.first : null;

  /// Get formatted duration (e.g., "3:45")
  String get formattedDuration {
    if (lengthMs == null) return '';
    final minutes = lengthMs! ~/ 60000;
    final seconds = ((lengthMs! % 60000) / 1000).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get display title with disambiguation
  String get displayTitle {
    if (disambiguation != null && disambiguation!.isNotEmpty) {
      return '$title ($disambiguation)';
    }
    return title;
  }

  /// Check if this recording has ISRC
  bool get hasISRC => isrcs.isNotEmpty;
}

/// Alias (alternative name) in MusicBrainz
@JsonSerializable()
class MusicBrainzAlias extends Equatable {
  final String name;
  final String? locale;
  final bool? primary;

  const MusicBrainzAlias({
    required this.name,
    this.locale,
    this.primary,
  });

  factory MusicBrainzAlias.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzAliasFromJson(json);

  Map<String, dynamic> toJson() => _$MusicBrainzAliasToJson(this);

  @override
  List<Object?> get props => [name, locale, primary];
}
