import 'package:flowgroove/models/link.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/services/csv/song_import_analyzer.dart';
import 'package:flowgroove/services/matching/song_merge_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Song song(
    String id,
    String title,
    String artist, {
    String? notes,
    int? bpm,
    String? variant,
    List<String> tags = const [],
    List<Link> links = const [],
  }) => Song(
    id: id,
    title: title,
    artist: artist,
    notes: notes,
    ourBPM: bpm,
    variantType: variant,
    tags: tags,
    links: links,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  group('SongImportAnalyzer', () {
    test('plans eight additions and eighteen persisted-target merges', () {
      final library = List.generate(
        18,
        (index) => song('library-$index', 'Existing $index', 'Artist $index'),
      );
      final imported = [
        ...List.generate(
          18,
          (index) => song('csv-$index', 'Existing $index', 'Artist $index'),
        ),
        ...List.generate(
          8,
          (index) => song('new-$index', 'New $index', 'New Artist $index'),
        ),
      ];

      final analysis = const SongImportAnalyzer().analyze(
        importedSongs: imported,
        librarySongs: library,
      );

      expect(analysis.rowsRead, 26);
      expect(analysis.songsToCreate, hasLength(8));
      expect(analysis.updates, hasLength(18));
      expect(analysis.mergedRowCount, 18);
      expect(
        analysis.updates.map((update) => update.merged.id),
        everyElement(startsWith('library-')),
      );
    });

    test('folds duplicate CSV rows into one planned addition', () {
      final analysis = const SongImportAnalyzer().analyze(
        importedSongs: [
          song('csv-1', 'New Song', 'Artist', tags: ['rock']),
          song('csv-2', 'New Song', 'Artist', tags: ['live']),
        ],
        librarySongs: const [],
      );

      expect(analysis.songsToCreate, hasLength(1));
      expect(analysis.songsToCreate.single.tags, ['rock', 'live']);
      expect(analysis.updates, isEmpty);
    });

    test('adds weak matches and different variants as new songs', () {
      final library = [song('library', 'My Song', 'The Band')];
      final analysis = const SongImportAnalyzer().analyze(
        importedSongs: [
          song('weak', 'My Other Song', 'The Band'),
          song('live', 'My Song (Live)', 'The Band', variant: 'live'),
        ],
        librarySongs: library,
      );

      expect(analysis.songsToCreate, hasLength(2));
      expect(analysis.updates, isEmpty);
    });

    test('accumulates multiple CSV rows into one library update', () {
      final library = song('library', 'Song', 'Artist', tags: ['saved']);
      final analysis = const SongImportAnalyzer().analyze(
        importedSongs: [
          song('csv-1', 'Song', 'Artist', tags: ['first']),
          song('csv-2', 'Song', 'Artist', tags: ['second']),
        ],
        librarySongs: [library],
      );

      expect(analysis.updates, hasLength(1));
      expect(analysis.updates.single.sources, hasLength(2));
      expect(analysis.updates.single.merged.tags, ['saved', 'first', 'second']);
    });
  });

  test('import merge keeps library values and fills blank fields', () {
    final library = song(
      'library',
      'Saved Title',
      'Saved Artist',
      notes: 'Saved notes',
      tags: ['saved'],
      links: [Link(type: Link.typeSpotify, url: 'https://song/1')],
    );
    final imported = song(
      'csv',
      'CSV Title',
      'CSV Artist',
      notes: 'CSV notes',
      bpm: 126,
      tags: ['Saved', 'csv'],
      links: [Link(type: Link.typeOther, url: 'https://song/2/')],
    );

    final merged = const SongMergeResolver().mergeImport(library, imported);

    expect(merged.id, 'library');
    expect(merged.title, 'Saved Title');
    expect(merged.artist, 'Saved Artist');
    expect(merged.notes, 'Saved notes');
    expect(merged.ourBPM, 126);
    expect(merged.tags, ['saved', 'csv']);
    expect(merged.links, hasLength(2));
  });
}
