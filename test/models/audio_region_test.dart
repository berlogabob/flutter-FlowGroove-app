import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var n = 0;
  String id() => 'r${n++}';
  setUp(() => n = 0);

  group('AudioGrid', () {
    const grid = AudioGrid(bpm: 120, offsetMs: 500); // 2000 ms bars

    test('bar math round-trips', () {
      expect(grid.barMs, 2000);
      expect(grid.barAt(4500), 2);
      expect(grid.msOfBar(2), 4500);
      expect(grid.barAt(0), -0.25);
    });

    test('snap goes to the nearest bar line inside the file', () {
      expect(grid.snap(5300, durationMs: 60000), 4500);
      expect(grid.snap(5600, durationMs: 60000), 6500);
      expect(grid.snap(100, durationMs: 60000), 500);
      expect(grid.snap(59900, durationMs: 60000), 60000);
    });
  });

  group('splitRegions', () {
    test('first split turns the whole file into two regions', () {
      final r = splitRegions(
        const [],
        atMs: 10000,
        durationMs: 30000,
        newId: id,
      );
      expect(
        [for (final x in r) (x.startMs, x.endMs)],
        [(0, 10000), (10000, 30000)],
      );
      expect(r.map((x) => x.id).toSet().length, 2);
    });

    test('cuts the region under the playhead, keeps its name left', () {
      final start = [
        const AudioRegion(id: 'a', name: 'Intro', startMs: 0, endMs: 8000),
        const AudioRegion(id: 'b', name: 'Verse', startMs: 8000, endMs: 20000),
      ];
      final r = splitRegions(start, atMs: 14000, durationMs: 20000, newId: id);
      expect(
        [for (final x in r) (x.name, x.startMs, x.endMs)],
        [('Intro', 0, 8000), ('Verse', 8000, 14000), ('', 14000, 20000)],
      );
    });

    test('a cut too close to a boundary is ignored', () {
      final start = [
        const AudioRegion(id: 'a', name: '', startMs: 0, endMs: 8000),
      ];
      expect(
        splitRegions(start, atMs: 200, durationMs: 8000, newId: id),
        same(start),
      );
      expect(
        splitRegions(start, atMs: 8000, durationMs: 8000, newId: id),
        same(start),
      );
    });
  });

  test('moveBoundary keeps both sides at least minRegionMs', () {
    final start = [
      const AudioRegion(id: 'a', name: '', startMs: 0, endMs: 4000),
      const AudioRegion(id: 'b', name: '', startMs: 4000, endMs: 8000),
    ];
    final r = moveBoundary(start, 0, 7900);
    expect(r[0].endMs, 8000 - minRegionMs);
    expect(r[1].startMs, 8000 - minRegionMs);
  });

  test('mergeRegion hands its time to a neighbour', () {
    final start = [
      const AudioRegion(id: 'a', name: 'A', startMs: 0, endMs: 4000),
      const AudioRegion(id: 'b', name: 'B', startMs: 4000, endMs: 8000),
      const AudioRegion(id: 'c', name: 'C', startMs: 8000, endMs: 9000),
    ];
    expect(
      [for (final x in mergeRegion(start, 1)) (x.id, x.endMs)],
      [('a', 8000), ('c', 9000)],
    );
    expect(
      [for (final x in mergeRegion(start, 0)) (x.id, x.startMs)],
      [('b', 0), ('c', 8000)],
    );
  });

  test('remapSelection follows regions, not indices, across a split', () {
    const before = [
      AudioRegion(id: 'a', name: 'Intro', startMs: 0, endMs: 4000),
      AudioRegion(id: 'b', name: 'Verse', startMs: 4000, endMs: 8000),
    ];
    var n = 0;
    String id() => 'n${n++}';
    // Split before the loop: Verse moves from index 1 to 2.
    final early = splitRegions(before, atMs: 2000, durationMs: 8000, newId: id);
    expect(remapSelection(before, early, (1, 1)), (2, 2));
    // Split inside the loop: the run covers both halves, same span.
    final inside = splitRegions(before, atMs: 6000, durationMs: 8000, newId: id);
    expect(remapSelection(before, inside, (1, 1)), (1, 2));
    expect(remapSelection(before, mergeRegion(before, 1), (0, 0)), (0, 0));
    expect(remapSelection(before, mergeRegion(before, 1), (1, 1)), null);
    expect(remapSelection(before, const [], (0, 1)), null);
  });

  test('toggleSelection builds contiguous runs', () {
    expect(toggleSelection(null, 2), (2, 2));
    expect(toggleSelection((2, 2), 3), (2, 3)); // transition drill
    expect(toggleSelection((2, 3), 0), (0, 3));
    expect(toggleSelection((0, 3), 3), (0, 2));
    expect(toggleSelection((0, 3), 0), (1, 3));
    expect(toggleSelection((0, 3), 1), (1, 1));
    expect(toggleSelection((1, 1), 1), isNull);
  });

  test('loopSpan adds pre-roll without going below zero', () {
    final regions = [
      const AudioRegion(id: 'a', name: '', startMs: 0, endMs: 4000),
      const AudioRegion(id: 'b', name: '', startMs: 4000, endMs: 8000),
      const AudioRegion(id: 'c', name: '', startMs: 8000, endMs: 12000),
    ];
    expect(loopSpan(regions, (1, 2), preRollMs: 2000), (2000, 12000));
    expect(loopSpan(regions, (0, 0), preRollMs: 2000), (0, 4000));
  });

  test('SongLabEntry round-trips grid and regions', () {
    final entry = SongLabEntry(
      id: 'e',
      songId: 's',
      type: LabEntryType.recording,
      authorId: 'u',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      grid: const AudioGrid(bpm: 98.5, offsetMs: 120, beatsPerBar: 3),
      regions: const [
        AudioRegion(
          id: 'a',
          name: 'Chorus',
          startMs: 0,
          endMs: 4000,
          sectionId: 'sec1',
        ),
      ],
    );
    final back = SongLabEntry.fromJson(entry.toJson());
    expect(back.grid!.bpm, 98.5);
    expect(back.grid!.offsetMs, 120);
    expect(back.grid!.beatsPerBar, 3);
    expect(back.regions.single.name, 'Chorus');
    expect(back.regions.single.sectionId, 'sec1');
  });

  group('linkToSongMap', () {
    const regions = [
      AudioRegion(id: 'a', name: 'Intro', startMs: 0, endMs: 1000),
      AudioRegion(id: 'b', name: 'Chorus', startMs: 1000, endMs: 2000),
      AudioRegion(id: 'c', name: '', startMs: 2000, endMs: 3000),
      AudioRegion(id: 'd', name: 'chorus', startMs: 3000, endMs: 4000),
    ];

    test('builds a map in play order when the song has none', () {
      final r = linkToSongMap(regions, const [], newId: id);
      expect(r.created!.map((s) => s.name), ['Intro', 'Chorus', 'chorus']);
      expect(r.regions[2].sectionId, isNull);
      expect([
        r.regions[0].sectionId,
        r.regions[1].sectionId,
        r.regions[3].sectionId,
      ], r.created!.map((s) => s.id).toList());
    });

    test('links the n-th occurrence and never rewrites an existing map', () {
      final sections = [
        Section(id: 's1', name: 'Chorus'),
        Section(id: 's2', name: 'Verse'),
        Section(id: 's3', name: 'Chorus'),
      ];
      final r = linkToSongMap(regions, sections, newId: id);
      expect(r.created, isNull);
      expect(r.regions.map((x) => x.sectionId), [null, 's1', null, 's3']);
      expect(r.unmatched, 1); // Intro has no counterpart
    });
  });

  group('click sync', () {
    test('only whole-BPM grids sync', () {
      expect(canSyncToClick(null), isFalse);
      expect(canSyncToClick(const AudioGrid(bpm: 120)), isTrue);
      expect(canSyncToClick(const AudioGrid(bpm: 98.5)), isFalse);
    });

    test('regionSpans maps regions to bars from the downbeat', () {
      const grid = AudioGrid(bpm: 120, offsetMs: 1000); // 2000 ms bars
      final spans = regionSpans(const [
        AudioRegion(id: 'pickup', name: '', startMs: 0, endMs: 1000),
        AudioRegion(id: 'intro', name: '', startMs: 1000, endMs: 9000),
        AudioRegion(id: 'verse', name: '', startMs: 9000, endMs: 25100),
      ], grid);
      expect(
        [for (final s in spans) (s.sectionId, s.startBar, s.bars)],
        [('intro', 0, 4), ('verse', 4, 8)],
      );
    });

    test('alignToDownbeat drops a pickup or pads silence', () {
      final pcm = Int16List.fromList(List.generate(10, (i) => i + 1));
      expect(alignToDownbeat(pcm, 3, 1000), [4, 5, 6, 7, 8, 9, 10]);
      expect(alignToDownbeat(pcm, -2, 1000).take(4), [0, 0, 1, 2]);
      expect(alignToDownbeat(pcm, 0, 1000), same(pcm));
    });
  });
}
