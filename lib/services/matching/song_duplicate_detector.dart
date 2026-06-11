import '../../models/song.dart';
import '../../models/song_duplicate.dart';
import 'match_scorer.dart';
import 'song_normalizer.dart';

class SongDuplicateDetector {
  const SongDuplicateDetector();

  List<SongDuplicateCandidate> findMatches(
    Song source,
    Iterable<Song> candidates, {
    bool includePossible = true,
  }) {
    final matches = <SongDuplicateCandidate>[];
    for (final candidate in candidates) {
      if (source.id.isNotEmpty && source.id == candidate.id) continue;
      final match = compare(source, candidate);
      if (match == null) continue;
      if (!includePossible &&
          match.confidence == SongDuplicateConfidence.possible) {
        continue;
      }
      matches.add(match);
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  List<SongDuplicateCandidate> findLibraryDuplicates(
    List<Song> songs, {
    bool includePossible = false,
  }) {
    final matches = <SongDuplicateCandidate>[];
    for (var i = 0; i < songs.length; i++) {
      matches.addAll(
        findMatches(
          songs[i],
          songs.skip(i + 1),
          includePossible: includePossible,
        ),
      );
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  SongDuplicateCandidate? compare(Song source, Song candidate) {
    final exactIdentity = _hasSharedIdentity(source, candidate);
    final exactNames =
        SongNormalizer.normalizeTitle(source.title) ==
            SongNormalizer.normalizeTitle(candidate.title) &&
        SongNormalizer.normalizeArtist(source.artist) ==
            SongNormalizer.normalizeArtist(candidate.artist) &&
        SongNormalizer.normalizeTitle(source.title).isNotEmpty;

    final rawScore = MatchScorer.calculate(
      inputTitle: source.title,
      inputArtist: source.artist,
      inputDuration: source.durationMs,
      inputAlbum: source.album,
      existingSong: candidate,
    );
    final score = exactIdentity || exactNames ? 100.0 : rawScore.total;
    if (score < MatchThresholds.REQUIRE_REVIEW) return null;

    final variantMismatch =
        _variant(source) != _variant(candidate) &&
        (_variant(source) != 'original' || _variant(candidate) != 'original');
    final confidence = variantMismatch
        ? SongDuplicateConfidence.possible
        : score >= MatchThresholds.EXACT_MATCH
        ? SongDuplicateConfidence.exact
        : score >= MatchThresholds.SUGGEST_MATCH
        ? SongDuplicateConfidence.strong
        : SongDuplicateConfidence.possible;

    return SongDuplicateCandidate(
      source: source,
      match: candidate,
      score: score,
      confidence: confidence,
      variantMismatch: variantMismatch,
    );
  }

  bool _hasSharedIdentity(Song a, Song b) {
    return _same(a.canonicalSongId, b.canonicalSongId) ||
        _same(a.musicbrainzId, b.musicbrainzId) ||
        _same(a.spotifyId, b.spotifyId) ||
        _same(a.isrc, b.isrc);
  }

  bool _same(String? a, String? b) =>
      a != null && a.isNotEmpty && b != null && a == b;

  String _variant(Song song) {
    if (song.variantType != null && song.variantType!.trim().isNotEmpty) {
      return song.variantType!.trim().toLowerCase();
    }
    final title = song.title.toLowerCase();
    for (final variant in const [
      'live',
      'acoustic',
      'remix',
      'instrumental',
      'demo',
      'cover',
      'karaoke',
    ]) {
      if (title.contains(variant)) return variant;
    }
    return 'original';
  }
}
