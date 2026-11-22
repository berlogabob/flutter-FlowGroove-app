import 'package:flowgroove/models/audio_region.dart' hide moveBoundary;
import 'package:flowgroove/screens/practice_regions/song_map/song_map_edit.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

const _grid = AudioGrid(bpm: 120);

AudioRegion _region(
  String id,
  String? section,
  int start,
  int end, {
  String? sectionId,
}) => AudioRegion(
  id: id,
  name: section == null ? id : '$section $id',
  section: section,
  sectionId: sectionId,
  startMs: _grid.msOfBar(start),
  endMs: _grid.msOfBar(end),
);

Iterable<int> _lengths(Iterable<AudioRegion> regions) =>
    regions.map((r) => r.lengthMs ~/ _grid.barMs);

void main() {
  final intro = _region('intro', null, 0, 2);
  final verseA = _region('a', 'Verse 1', 2, 6, sectionId: 'verse');
  final verseB = _region('b', 'Verse 1', 6, 14, sectionId: 'verse');
  final chorusA = _region('c', 'Chorus 1', 14, 22, sectionId: 'chorus');
  final chorusB = _region('d', 'Chorus 1', 22, 23, sectionId: 'chorus');
  final outro = _region('outro', null, 23, 25);
  final regions = List<AudioRegion>.unmodifiable([
    intro,
    verseA,
    verseB,
    chorusA,
    chorusB,
    outro,
  ]);

  test('moving a section renumbers both groups and keeps its linked parts', () {
    final verseRepeat = _region('e', 'Verse 2', 23, 25, sectionId: 'verse-2');
    final customPart = verseB.copyWith(name: 'Pickup');
    final input = [intro, verseA, customPart, chorusA, chorusB, verseRepeat];
    final view = SongMapView(regions: input, durationMs: verseRepeat.endMs);
    addTearDown(view.dispose);

    final edited = editSectionName(
      view,
      occurrenceId: verseA.id,
      name: 'Chorus',
      move: true,
    );

    expect(edited.map((r) => r.section), [
      null,
      'Chorus 1',
      'Chorus 1',
      'Chorus 2',
      'Chorus 2',
      'Verse 1',
    ]);
    expect(edited.map((r) => r.sectionId), input.map((r) => r.sectionId));
    expect(
      edited.map((r) => (r.id, r.startMs, r.endMs)),
      input.map((r) => (r.id, r.startMs, r.endMs)),
    );
    expect(edited.map((r) => r.name), [
      'intro',
      'Chorus 1 a',
      'Pickup',
      'Chorus 2 c',
      'Chorus 2 d',
      'Verse 1 e',
    ]);
  });

  test('moveBoundary rebuilds both sections and leaves an undo snapshot', () {
    final edited = moveBoundary(regions, 2, 34000, grid: _grid);
    final verse = edited.where((r) => r.sectionId == 'verse');
    final chorus = edited.where((r) => r.sectionId == 'chorus');
    expect(_lengths(verse), [8, 4, 2, 1]);
    expect(_lengths(chorus), [4, 2]);
    expect(verse.last.endMs, 34000);
    expect(chorus.first.startMs, 34000);
    expect(edited.first, same(intro));
    expect(edited.last, same(outro));
    expect(edited.map((r) => r.id).toSet(), hasLength(edited.length));
    expect(regions[2].endMs, 28000);
    expect(regions[3].startMs, 28000);
  });

  test(
    'moveBoundary clamps at a bar from either neighbouring section edge',
    () {
      final earlier = moveBoundary(regions, 2, 0, grid: _grid);
      final later = moveBoundary(regions, 2, 60000, grid: _grid);
      expect(earlier.where((r) => r.sectionId == 'verse').last.endMs, 6000);
      expect(later.where((r) => r.sectionId == 'chorus').first.startMs, 44000);
      expect(moveBoundary(regions, 5, 50000, grid: _grid), same(regions));
    },
  );

  test('moveBoundary keeps a legal part seam inside a section', () {
    final edited = moveBoundary(regions, 1, 16000, grid: _grid);
    final verse = edited.where((r) => r.sectionId == 'verse');
    expect(_lengths(verse), [4, 2, 4, 2]);
    expect(verse.elementAt(1).endMs, 16000);
    expect(moveBoundary(regions, 1, 14000, grid: _grid), same(regions));
  });

  test('deleteBoundary merges complete sections under the left name', () {
    final edited = deleteBoundary(regions, 2, grid: _grid);
    final merged = edited.sublist(1, edited.length - 1);
    expect(_lengths(merged), [8, 8, 4, 1]);
    expect(merged.map((r) => r.section).toSet(), {'Verse 1'});
    expect(merged.map((r) => r.sectionId).toSet(), {'verse'});
    expect(merged.first.startMs, verseA.startMs);
    expect(merged.last.endMs, chorusB.endMs);
    expect(edited.first, same(intro));
    expect(edited.last, same(outro));
    expect(deleteBoundary(regions, -1, grid: _grid), same(regions));
  });

  test('deleteBoundary can remove a part seam while keeping legal lengths', () {
    final input = [_region('a', 'Verse', 0, 8), _region('b', 'Verse', 8, 16)];
    final edited = deleteBoundary(input, 0, grid: _grid);
    expect(_lengths(edited), [4, 8, 4]);
    expect(edited.map((r) => r.endMs), isNot(contains(16000)));
  });

  test('mergePadRange rebuilds three sections under the first section', () {
    final view = SongMapView(regions: regions, durationMs: outro.endMs);
    addTearDown(view.dispose);

    final edited = mergePadRange(view, 1, 3, grid: _grid);
    final merged = edited.skip(1);
    expect(edited.first, same(intro));
    expect(merged.first.id, verseA.id);
    expect(merged.first.startMs, verseA.startMs);
    expect(merged.last.endMs, outro.endMs);
    expect(merged.map((r) => r.section).toSet(), {'Verse 1'});
    expect(merged.map((r) => r.sectionId).toSet(), {'verse'});
    expect(_lengths(merged), [8, 8, 4, 2, 1]);
    expect(view.regions, same(regions));
  });

  test('mergePadRange combines selected parts within their section', () {
    final verseC = _region('e', 'Verse 1', 14, 15, sectionId: 'verse');
    final input = [intro, verseA, verseB, verseC];
    final view = SongMapView(regions: input, durationMs: verseC.endMs)
      ..zoomIn(1);
    addTearDown(view.dispose);

    final edited = mergePadRange(view, 0, 2, grid: _grid);
    expect(edited, hasLength(2));
    expect(edited.first, same(intro));
    expect(edited.last.toJson(), verseA.copyWith(endMs: verseC.endMs).toJson());
  });

  test('mergePadRange keeps a repeated legacy section outside the range', () {
    final first = _region('first', 'Verse', 0, 4);
    final middle = _region('middle', 'Chorus', 4, 8);
    final last = _region('last', 'Verse', 8, 12);
    final view = SongMapView(
      regions: [first, middle, last],
      durationMs: last.endMs,
    );
    addTearDown(view.dispose);

    final edited = mergePadRange(view, 0, 1, grid: _grid);
    final mergedView = SongMapView(regions: edited, durationMs: last.endMs);
    addTearDown(mergedView.dispose);
    expect(mergedView.sections.map((r) => r.id), ['first', 'last']);
    expect(mergedView.sections.first.endMs, middle.endMs);
    expect(edited.last, same(last));
  });

  test('splitAt names the new section with the first unused letter', () {
    final partA = _region('part-a', 'Part A 2', 0, 2);
    final partC = _region('part-c', 'Part C 1', 14, 23);
    final input = [partA, verseA, verseB, partC];
    final edited = splitAt(input, 12000, grid: _grid);
    expect(_lengths(edited), [2, 4, 8, 9]);
    expect(edited[2].section, 'Part B 1');
    expect(edited[2].name, 'Part B 1 a');
    expect(edited[2].sectionId, isNull);
    expect(edited[1].sectionId, 'verse');
    expect(edited[2].startMs, edited[1].endMs);
    expect(edited.first, same(partA));
    expect(edited.last, same(partC));
  });

  test('splitAt refuses short remnants and existing section boundaries', () {
    for (final ms in [-1, 0, 3000, 4000, 27000, 28000, 50000]) {
      expect(splitAt(regions, ms, grid: _grid), same(regions), reason: '$ms');
    }
  });

  test(
    'moveBoundary uses caller timing and the offset fractional bar grid',
    () {
      const grid = AudioGrid(bpm: 137, beatsPerBar: 3, offsetMs: 233);
      final input = [
        AudioRegion(id: 'a', name: 'A', startMs: 0, endMs: grid.msOfBar(8)),
        AudioRegion(
          id: 'b',
          name: 'B',
          startMs: grid.msOfBar(8),
          endMs: grid.msOfBar(21),
        ),
      ];
      final cut = snapToBeat(grid, grid.msOfBar(10) + 400, durationMs: 30000);
      final edited = moveBoundary(input, 0, cut, grid: grid);
      expect(edited.where((r) => r.section == 'A').last.endMs, cut);
      expect(edited.where((r) => r.section == 'B').first.startMs, cut);
      expect(edited.last.endMs, input.last.endMs);
      for (var i = 1; i < edited.length; i++) {
        expect(edited[i - 1].endMs, edited[i].startMs);
        expect(edited[i].lengthMs, greaterThan(0));
      }
    },
  );
}
