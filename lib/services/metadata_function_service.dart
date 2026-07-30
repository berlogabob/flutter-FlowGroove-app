import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Everything the server could find about one track, plus where each field came
/// from.
///
/// `sources` maps a field name to its provider ("spotify", "musicbrainz",
/// "deezer", "lyrics.ovh"). A field with no entry was not sourced from anywhere,
/// which is how the UI can avoid presenting a blank or a guess as fact.
///
/// Note there is deliberately no key: no metadata provider exposes musical key.
/// Spotify's audio-features endpoint returns 403 for this app (Development mode,
/// post-Nov-2024 deprecation), and its old `?? 0` fallback silently produced
/// "C major from Spotify" for any response missing a key — which is a large part
/// of why this library accumulated phantom C values.
@immutable
class TrackMetadata {
  const TrackMetadata({
    required this.found,
    required this.title,
    required this.artist,
    this.album,
    this.releaseYear,
    this.durationMs,
    this.isrc,
    this.spotifyId,
    this.musicBrainzId,
    this.musicBrainzWorkId,
    this.iswc,
    this.deezerId,
    this.bpm,
    this.sections = const [],
    this.sources = const {},
    this.missing = const [],
  });

  factory TrackMetadata.fromMap(Map<String, dynamic> map) {
    return TrackMetadata(
      found: map['found'] == true,
      title: (map['title'] as String?) ?? '',
      artist: (map['artist'] as String?) ?? '',
      album: map['album'] as String?,
      releaseYear: (map['releaseYear'] as num?)?.toInt(),
      durationMs: (map['durationMs'] as num?)?.toInt(),
      isrc: map['isrc'] as String?,
      spotifyId: map['spotifyId'] as String?,
      musicBrainzId: map['musicBrainzId'] as String?,
      musicBrainzWorkId: map['musicBrainzWorkId'] as String?,
      iswc: map['iswc'] as String?,
      deezerId: map['deezerId'] as String?,
      bpm: (map['bpm'] as num?)?.toInt(),
      sections: ((map['sections'] as List<dynamic>?) ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (s) => LyricSection(
              name: (s['name'] as String?) ?? 'Section',
              chart: (s['chart'] as String?) ?? '',
            ),
          )
          .toList(),
      sources: ((map['sources'] as Map<dynamic, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      missing: ((map['missing'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  final bool found;
  final String title;
  final String artist;
  final String? album;
  final int? releaseYear;
  final int? durationMs;
  final String? isrc;
  final String? spotifyId;
  final String? musicBrainzId;
  final String? musicBrainzWorkId;
  final String? iswc;
  final String? deezerId;

  /// Beats per minute, from Deezer. Absent when unknown.
  ///
  /// Treat as fill-only-if-blank: Deezer reports double-time for some tracks
  /// (196 against a true ~98 for "Sweet Home Alabama"), so overwriting a tempo a
  /// musician set by hand does more harm than leaving it.
  final int? bpm;

  final List<LyricSection> sections;
  final Map<String, String> sources;
  final List<String> missing;

  /// The provider that supplied [field], or null if nothing did.
  String? sourceOf(String field) => sources[field];
}

/// One stanza of lyrics, already labelled Verse N / Chorus by the server.
@immutable
class LyricSection {
  const LyricSection({required this.name, required this.chart});

  final String name;
  final String chart;
}

/// Callable wrapper for the server-side metadata resolver.
///
/// The client used to fan out to MusicBrainz, Deezer and Spotify itself, which
/// required the Spotify client secret to exist in the app bundle and duplicated
/// the album-selection heuristic between Dart and the agent path. Fixing one
/// never fixed the other — which is how canonical songs ended up pointing at
/// bootleg albums ("Apocalypse Now" as the album for Light My Fire).
///
/// Search/autocomplete still happens client-side against the canonical catalog
/// and MusicBrainz, both of which are keyless and reachable from web without a
/// proxy. This service covers the enrichment step after a match is chosen.
class MetadataFunctionService {
  MetadataFunctionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Resolves one track. Returns null on any failure — autofill must never break
  /// the form, matching the "never throws" contract the old direct API services
  /// had.
  ///
  /// [skip] can drop slow providers by name ('lyrics', 'deezer', 'spotify',
  /// 'musicbrainz').
  Future<TrackMetadata?> lookup({
    required String title,
    String? artist,
    List<String> skip = const [],
  }) async {
    if (title.trim().isEmpty) return null;
    try {
      final callable = _functions.httpsCallable('lookupTrackMetadata');
      final result = await callable.call<Map<String, dynamic>>({
        'title': title.trim(),
        if (artist != null && artist.trim().isNotEmpty) 'artist': artist.trim(),
        if (skip.isNotEmpty) 'skip': skip,
      });
      return TrackMetadata.fromMap(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('lookupTrackMetadata failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('lookupTrackMetadata failed: $e');
      return null;
    }
  }
}
