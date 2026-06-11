import 'song.dart';

class SongImportMerge {
  const SongImportMerge({
    required this.keeper,
    required this.duplicate,
    required this.merged,
  });

  final Song keeper;
  final Song duplicate;
  final Song merged;
}

class SongImportPlan {
  const SongImportPlan({required this.songsToCreate, required this.merges});

  final List<Song> songsToCreate;
  final List<SongImportMerge> merges;
}
