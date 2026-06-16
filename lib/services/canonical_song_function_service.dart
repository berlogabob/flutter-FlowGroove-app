import 'package:cloud_functions/cloud_functions.dart';

import '../models/song_suggestion.dart';

class EnsureCanonicalSongResult {
  const EnsureCanonicalSongResult({
    required this.canonicalSongId,
    required this.canonicalRevision,
  });

  final String canonicalSongId;
  final int canonicalRevision;
}

class CanonicalSongFunctionService {
  CanonicalSongFunctionService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<EnsureCanonicalSongResult> ensureCanonicalSong({
    required String title,
    required String artist,
    String? musicBrainzId,
    String? isrc,
    String? spotifyId,
    String? album,
    int? durationMs,
  }) async {
    final callable = _functions.httpsCallable('ensureCanonicalSong');
    final result = await callable.call<Map<String, dynamic>>(
      _withoutNullValues({
        'title': title,
        'artist': artist,
        'musicBrainzId': musicBrainzId,
        'isrc': isrc,
        'spotifyId': spotifyId,
        'album': album,
        'durationMs': durationMs,
      }),
    );

    return _parseResult(result.data);
  }

  Future<EnsureCanonicalSongResult> ensureFromSuggestion(
    SongSuggestion suggestion,
  ) {
    return ensureCanonicalSong(
      title: suggestion.title,
      artist: suggestion.artist,
      musicBrainzId: suggestion.musicBrainzId,
      album: suggestion.album,
      durationMs: suggestion.durationMs,
    );
  }

  EnsureCanonicalSongResult _parseResult(Map<String, dynamic> data) {
    final canonicalSongId = data['canonicalSongId'] as String?;
    final canonicalRevision = (data['canonicalRevision'] as num?)?.toInt();
    if (canonicalSongId == null ||
        canonicalSongId.isEmpty ||
        canonicalRevision == null) {
      throw const FormatException('Invalid ensureCanonicalSong response.');
    }

    return EnsureCanonicalSongResult(
      canonicalSongId: canonicalSongId,
      canonicalRevision: canonicalRevision,
    );
  }
}

Map<String, Object?> _withoutNullValues(Map<String, Object?> values) {
  return Map.fromEntries(values.entries.where((entry) => entry.value != null));
}
