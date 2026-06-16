import 'song.dart';

class SongImportUpdate {
  const SongImportUpdate({
    required this.original,
    required this.merged,
    required this.sources,
  });

  final Song original;
  final Song merged;
  final List<Song> sources;
}

class SongImportAnalysis {
  const SongImportAnalysis({
    required this.rowsRead,
    required this.songsToCreate,
    required this.updates,
    required this.errors,
    required this.warnings,
  });

  final int rowsRead;
  final List<Song> songsToCreate;
  final List<SongImportUpdate> updates;
  final List<String> errors;
  final List<String> warnings;

  int get mergedRowCount =>
      updates.fold(0, (count, update) => count + update.sources.length);
  int get validRowCount => rowsRead - errors.length;
  bool get hasWork => songsToCreate.isNotEmpty || updates.isNotEmpty;
}

class SongImportExecutionResult {
  const SongImportExecutionResult({
    required this.added,
    required this.merged,
    required this.failures,
    required this.warnings,
  });

  final int added;
  final int merged;
  final List<String> failures;
  final List<String> warnings;
}
