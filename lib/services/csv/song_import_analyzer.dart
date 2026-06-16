import '../../models/song.dart';
import '../../models/song_duplicate.dart';
import '../../models/song_import_plan.dart';
import '../matching/song_duplicate_detector.dart';
import '../matching/song_merge_resolver.dart';

class SongImportAnalyzer {
  const SongImportAnalyzer({
    this.autoMergeThreshold = 90,
    this.detector = const SongDuplicateDetector(),
    this.resolver = const SongMergeResolver(),
  });

  final double autoMergeThreshold;
  final SongDuplicateDetector detector;
  final SongMergeResolver resolver;

  SongImportAnalysis analyze({
    required List<Song> importedSongs,
    required List<Song> librarySongs,
    List<String> errors = const [],
    List<String> warnings = const [],
  }) {
    final additions = <Song>[];
    final updates = <String, _MutableUpdate>{};

    for (final imported in importedSongs) {
      final libraryMatch = _bestAutomaticMatch(imported, librarySongs);
      if (libraryMatch != null) {
        final existing = updates[libraryMatch.match.id];
        final base = existing?.merged ?? libraryMatch.match;
        updates[libraryMatch.match.id] = _MutableUpdate(
          original: existing?.original ?? libraryMatch.match,
          merged: resolver.mergeImport(base, imported),
          sources: [...?existing?.sources, imported],
        );
        continue;
      }

      final additionMatch = _bestAutomaticMatch(imported, additions);
      if (additionMatch != null) {
        final index = additions.indexWhere(
          (song) => song.id == additionMatch.match.id,
        );
        additions[index] = resolver.mergeImport(additions[index], imported);
        continue;
      }

      additions.add(imported);
    }

    return SongImportAnalysis(
      rowsRead: importedSongs.length + errors.length,
      songsToCreate: additions,
      updates: updates.values
          .map(
            (update) => SongImportUpdate(
              original: update.original,
              merged: update.merged,
              sources: update.sources,
            ),
          )
          .toList(),
      errors: errors,
      warnings: warnings,
    );
  }

  SongDuplicateCandidate? _bestAutomaticMatch(
    Song source,
    Iterable<Song> candidates,
  ) {
    for (final match in detector.findMatches(source, candidates)) {
      if (match.variantMismatch) continue;
      if (match.confidence == SongDuplicateConfidence.exact ||
          match.score >= autoMergeThreshold) {
        return match;
      }
    }
    return null;
  }
}

class _MutableUpdate {
  const _MutableUpdate({
    required this.original,
    required this.merged,
    required this.sources,
  });

  final Song original;
  final Song merged;
  final List<Song> sources;
}
