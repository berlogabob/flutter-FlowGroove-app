import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/link.dart';
import '../../models/section.dart';
import '../../models/song.dart';
import '../csv/song_csv_parser.dart' show SongParseResult;
import '../csv/song_csv_schema.dart' show SongCsvValidation;

/// FlowGroove **Song JSON v1** — the stable, documented import/export format that
/// AI prompt templates (#73) and the MCP endpoint (#74) write against.
///
/// Schema: `docs/SONG_JSON_SCHEMA.md`. Envelope:
/// `{ "schemaVersion": 1, "songs": [ {song}, ... ] }`. [parse] also accepts a bare
/// song array or a single song object for convenience.
class SongJsonCodec {
  const SongJsonCodec();

  static const int schemaVersion = 1;
  static const _uuid = Uuid();

  static const _knownSongKeys = {
    'id', 'title', 'artist', 'originalKey', 'ourKey', 'originalBPM', 'ourBPM',
    'notes', 'tags', 'spotifyUrl', 'links', 'sections',
    'spotifyId', 'musicbrainzId', 'isrc', 'album', 'durationMs',
  };

  // ---- Export ----

  String exportToString(List<Song> songs) {
    final map = {
      'schemaVersion': schemaVersion,
      'songs': songs.map(_songToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  String exportSong(Song song) => exportToString([song]);

  Map<String, dynamic> _songToMap(Song s) => {
    'title': s.title,
    'artist': s.artist,
    if (s.originalKey != null) 'originalKey': s.originalKey,
    if (s.ourKey != null) 'ourKey': s.ourKey,
    if (s.originalBPM != null) 'originalBPM': s.originalBPM,
    if (s.ourBPM != null) 'ourBPM': s.ourBPM,
    if (s.notes != null && s.notes!.isNotEmpty) 'notes': s.notes,
    if (s.tags.isNotEmpty) 'tags': s.tags,
    if (s.spotifyUrl != null) 'spotifyUrl': s.spotifyUrl,
    if (s.links.isNotEmpty) 'links': s.links.map((l) => l.toJson()).toList(),
    if (s.sections.isNotEmpty)
      'sections': s.sections.map((x) => x.toJson()).toList(),
    if (s.spotifyId != null) 'spotifyId': s.spotifyId,
    if (s.musicbrainzId != null) 'musicbrainzId': s.musicbrainzId,
    if (s.isrc != null) 'isrc': s.isrc,
    if (s.album != null) 'album': s.album,
    if (s.durationMs != null) 'durationMs': s.durationMs,
  };

  // ---- Import ----

  SongParseResult parse(String jsonStr) {
    final errors = <String>[];
    final warnings = <String>[];

    dynamic decoded;
    try {
      decoded = json.decode(jsonStr);
    } catch (e) {
      return SongParseResult(successful: const [], errors: ['Invalid JSON: $e']);
    }

    final List<dynamic> rawSongs;
    if (decoded is Map<String, dynamic>) {
      final v = decoded['schemaVersion'];
      if (v != null && v != schemaVersion) {
        warnings.add(
          'Unknown schemaVersion "$v" (expected $schemaVersion); '
          'attempting a best-effort import.',
        );
      }
      if (decoded['songs'] is List) {
        rawSongs = decoded['songs'] as List;
      } else if (decoded.containsKey('title')) {
        rawSongs = [decoded]; // a single bare song object
      } else {
        return SongParseResult(
          successful: const [],
          errors: ['Expected a "songs" array or a single song object.'],
          warnings: warnings,
        );
      }
    } else if (decoded is List) {
      rawSongs = decoded;
    } else {
      return SongParseResult(
        successful: const [],
        errors: ['Top-level JSON must be an object or an array.'],
      );
    }

    final songs = <Song>[];
    for (var i = 0; i < rawSongs.length; i++) {
      final raw = rawSongs[i];
      if (raw is! Map<String, dynamic>) {
        errors.add('Song #${i + 1}: expected an object.');
        continue;
      }
      final song = _songFromMap(raw, i + 1, errors, warnings);
      if (song != null) songs.add(song);
    }
    return SongParseResult(successful: songs, errors: errors, warnings: warnings);
  }

  Song? _songFromMap(
    Map<String, dynamic> m,
    int idx,
    List<String> errors,
    List<String> warnings,
  ) {
    final title = (m['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      errors.add('Song #$idx: "title" is required.');
      return null;
    }

    final unknown = m.keys.where((k) => !_knownSongKeys.contains(k)).toList();
    if (unknown.isNotEmpty) {
      warnings.add('Song #$idx ("$title"): ignored unknown field(s): '
          '${unknown.join(', ')}.');
    }

    final originalKey = _key(m['originalKey'], 'originalKey', title, idx, errors);
    final ourKey = _key(m['ourKey'], 'ourKey', title, idx, errors);
    final originalBpm = _bpm(m['originalBPM'], 'originalBPM', title, idx, errors);
    final ourBpm = _bpm(m['ourBPM'], 'ourBPM', title, idx, errors);
    final spotifyUrl = m['spotifyUrl'] as String?;
    if (spotifyUrl != null && !SongCsvValidation.isValidUrl(spotifyUrl)) {
      errors.add('Song #$idx ("$title"): invalid spotifyUrl "$spotifyUrl".');
    }

    final now = DateTime.now();
    return Song(
      id: _uuid.v4(),
      title: title,
      artist: (m['artist'] as String?)?.trim() ?? '',
      createdAt: now,
      updatedAt: now,
      originalKey: originalKey,
      ourKey: ourKey,
      originalBPM: originalBpm,
      ourBPM: ourBpm,
      notes: m['notes'] as String?,
      tags: (m['tags'] as List?)?.whereType<String>().toList() ?? const [],
      spotifyUrl: spotifyUrl,
      links: _links(m['links'], title, idx, errors),
      sections: _sections(m['sections']),
      spotifyId: m['spotifyId'] as String?,
      musicbrainzId: m['musicbrainzId'] as String?,
      isrc: m['isrc'] as String?,
      album: m['album'] as String?,
      durationMs: (m['durationMs'] as num?)?.toInt(),
    );
  }

  String? _key(
    dynamic v,
    String field,
    String title,
    int idx,
    List<String> errors,
  ) {
    if (v == null) return null;
    final key = v.toString();
    if (!SongCsvValidation.isValidKey(key)) {
      errors.add('Song #$idx ("$title"): invalid $field "$key" '
          '(expected like C, G#, Am, Bbm).');
      return null;
    }
    return key;
  }

  int? _bpm(
    dynamic v,
    String field,
    String title,
    int idx,
    List<String> errors,
  ) {
    if (v == null) return null;
    if (!SongCsvValidation.isValidBpm(v)) {
      errors.add('Song #$idx ("$title"): invalid $field "$v" (expected 40-300).');
      return null;
    }
    return (v as num).toInt();
  }

  List<Link> _links(dynamic v, String title, int idx, List<String> errors) {
    if (v is! List) return const [];
    final links = <Link>[];
    for (final e in v) {
      if (e is! Map<String, dynamic>) continue;
      final url = (e['url'] as String?) ?? '';
      if (url.isNotEmpty && !SongCsvValidation.isValidUrl(url)) {
        errors.add('Song #$idx ("$title"): invalid link url "$url".');
        continue;
      }
      links.add(Link.fromJson(e));
    }
    return links;
  }

  List<Section> _sections(dynamic v) {
    if (v is! List) return const [];
    final sections = <Section>[];
    for (final e in v) {
      if (e is! Map<String, dynamic>) continue;
      sections.add(
        Section(
          id: (e['id'] as String?) ?? _uuid.v4(),
          name: (e['name'] as String?)?.trim().isNotEmpty == true
              ? (e['name'] as String).trim()
              : 'Section',
          notes: (e['notes'] as String?) ?? '',
          duration: (e['duration'] as num?)?.toInt() ?? 1,
          colorValue: (e['colorValue'] as num?)?.toInt(),
          chordChart: e['chordChart'] as String?,
        ),
      );
    }
    return sections;
  }
}
