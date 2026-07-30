import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'musicbrainz_recording.g.dart';

/// Artist credit in MusicBrainz response
@JsonSerializable()
class MusicBrainzArtistCredit extends Equatable {
  const MusicBrainzArtistCredit({
    required this.artist,
    this.name,
    this.joinPhrase,
  });

  factory MusicBrainzArtistCredit.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzArtistCreditFromJson(json);

  final MusicBrainzArtist artist;
  final String? name;
  final String? joinPhrase;

  Map<String, dynamic> toJson() => _$MusicBrainzArtistCreditToJson(this);

  @override
  List<Object?> get props => [artist.id, name, joinPhrase];

  String get displayName => name ?? artist.name;
}

/// Artist in MusicBrainz response
@JsonSerializable()
class MusicBrainzArtist extends Equatable {
  const MusicBrainzArtist({
    required this.id,
    required this.name,
    this.disambiguation,
    this.sortName,
  });

  factory MusicBrainzArtist.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzArtistFromJson(json);

  final String id;
  final String name;
  final String? disambiguation;
  final String? sortName;

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
  const MusicBrainzRelease({
    required this.id,
    required this.title,
    this.date,
    this.country,
  });

  factory MusicBrainzRelease.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzReleaseFromJson(json);

  // NOTE: no `media` field — the API sends it as a list of objects, and the
  // old List<String> typing made every fromJson throw, silently killing all
  // MusicBrainz autofill suggestions (#75/#78). It was never read; if it's
  // ever needed, model it as its own class.

  final String id;
  final String title;
  final String? date;
  final String? country;

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
  /// The release this recording most likely originally came from.
  ///
  /// NOT `releases.first`: MusicBrainz returns releases in arbitrary order, so
  /// the first one is routinely a live album, bootleg or compilation. That single
  /// line is why canonical songs in production ended up with "Apocalypse Now" as
  /// the album for Light My Fire and "Live at Leeds" for Pinball Wizard.
  ///
  /// The earliest dated release is a decent proxy for the original. It is only a
  /// proxy — the authoritative album now comes from the server-side resolver via
  /// the lookupTrackMetadata callable, which picks by Spotify album_type and was
  /// measured correct on 6/6 of a hard sample. This getter is what the suggestion
  /// list shows before that call, and the fallback when the resolver finds
  /// nothing.
  MusicBrainzRelease? get _earliestRelease {
    if (releases.isEmpty) return null;
    final dated = releases.where((r) => (r.date ?? '').isNotEmpty).toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
    return dated.isNotEmpty ? dated.first : releases.first;
  }

  int? get releaseYear => _earliestRelease?.releaseYear;

  /// Album title of the earliest dated release.
  String? get album => _earliestRelease?.title;

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
  const MusicBrainzAlias({
    required this.name,
    this.locale,
    this.primary,
  });

  factory MusicBrainzAlias.fromJson(Map<String, dynamic> json) =>
      _$MusicBrainzAliasFromJson(json);

  final String name;
  final String? locale;
  final bool? primary;

  Map<String, dynamic> toJson() => _$MusicBrainzAliasToJson(this);

  @override
  List<Object?> get props => [name, locale, primary];
}
