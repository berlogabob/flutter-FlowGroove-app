import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_names.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

AudioRegion _r(String id, String? section, int start, int end, {String? sid}) =>
    AudioRegion(
      id: id,
      name: section == null ? id : '$section a',
      section: section,
      sectionId: sid ?? (section == null ? null : 'id-$id'),
      startMs: start * 1000,
      endMs: end * 1000,
    );

List<String?> _sections(List<AudioRegion> regions) => [
  for (final r in regions) r.section,
];

void main() {
  test('a split in the middle renames the new half and shifts the rest', () {
    final out = normalizeAutoSectionNames([
      _r('1', 'Part A 1', 0, 8),
      _r('2', 'Part B 1', 8, 12),
      _r('3', 'Part A 1', 12, 16, sid: 'new'),
      _r('4', 'Part C 1', 16, 24),
    ]);
    // Badges: A, B, C(new group "Part A"), D ... groups are by name, so the
    // second "Part A 1" shares badge A and becomes occurrence 2.
    expect(_sections(out), ['Part A 1', 'Part B 1', 'Part A 2', 'Part C 1']);
    expect(out[2].name, 'Part A 2 a');
    expect(out[2].sectionId, 'new');
  });

  test('a new letter inserted before old ones shifts them in step', () {
    final out = normalizeAutoSectionNames([
      _r('1', 'Part A 1', 0, 8),
      _r('2', 'Part A 1', 8, 12, sid: 'new'),
      _r('3', 'Part B 1', 12, 16),
    ]);
    expect(_sections(out), ['Part A 1', 'Part A 2', 'Part B 1']);

    final shifted = normalizeAutoSectionNames([
      _r('1', 'Part A 1', 0, 8),
      _r('2', 'Part D 1', 8, 12),
      _r('3', 'Part B 1', 12, 16),
    ]);
    expect(_sections(shifted), ['Part A 1', 'Part B 1', 'Part C 1']);
    expect(shifted[1].name, 'Part B 1 a');
  });

  test('repeats keep the letter and count occurrences', () {
    final out = normalizeAutoSectionNames([
      _r('1', 'Part A 1', 0, 4),
      _r('2', 'Part B 1', 4, 8),
      _r('3', 'Part B 7', 8, 12),
      _r('4', 'Part A 1', 12, 16),
    ]);
    expect(_sections(out), ['Part A 1', 'Part B 1', 'Part B 2', 'Part A 2']);
  });

  test('merging two sections renumbers what follows', () {
    final merged = [_r('1', 'Part A 1', 0, 8), _r('3', 'Part A 3', 12, 16)];
    expect(_sections(normalizeAutoSectionNames(merged)), [
      'Part A 1',
      'Part A 2',
    ]);
  });

  test('typed and semantic names are never changed', () {
    final input = [
      _r('1', 'Intro', 0, 4),
      _r('2', 'My riff', 4, 8),
      _r('3', 'Part Z 4', 8, 12),
      _r('4', 'Verse 2', 12, 16),
      _r('5', 'Part B', 16, 20),
    ];
    final out = normalizeAutoSectionNames(input);
    expect(_sections(out), [
      'Intro',
      'My riff',
      'Part C 1',
      'Verse 2',
      'Part B',
    ]);
    expect(out[0], same(input[0]));
  });

  test('a group mixing auto and typed names is left alone', () {
    final input = [_r('1', 'Part B', 0, 4), _r('2', 'Part B 5', 4, 8)];
    expect(normalizeAutoSectionNames(input), same(input));
  });

  test('a rename that would merge two groups is skipped', () {
    final input = [
      _r('1', 'Part C 1', 0, 4),
      _r('2', 'Part A', 4, 8),
      _r('3', 'Part B', 8, 12),
    ];
    expect(_sections(normalizeAutoSectionNames(input)), _sections(input));
  });

  test('legacy sections without ids rename their own region', () {
    final out = normalizeAutoSectionNames([
      const AudioRegion(id: 'x', name: 'Part C 1', startMs: 0, endMs: 1000),
      const AudioRegion(id: 'y', name: 'Part A 1', startMs: 1000, endMs: 2000),
    ]);
    expect([for (final r in out) r.name], ['Part A 1', 'Part B 1']);
    expect(out[0].section, isNull);
  });

  test('is idempotent and returns the same list when nothing changes', () {
    final once = normalizeAutoSectionNames([
      _r('1', 'Part A 1', 0, 8),
      _r('2', 'Part E 1', 8, 12),
      _r('3', 'Part A 1', 12, 16),
      _r('4', 'Part B 3', 16, 20),
    ]);
    final twice = normalizeAutoSectionNames(once);
    expect(twice, same(once));
    expect(normalizeAutoSectionNames(const []), isEmpty);
  });

  group('Chop on the Song Map', () {
    const grid = AudioGrid(bpm: 120);
    final regions = [
      for (final (i, letter) in ['A', 'B', 'C', 'D'].indexed)
        AudioRegion(
          id: 'r$i',
          name: 'Part $letter 1 a',
          section: 'Part $letter 1',
          sectionId: 's$i',
          startMs: grid.msOfBar(i * 4),
          endMs: grid.msOfBar(i * 4 + 4),
        ),
    ];
    final fixture = PracticeRegionsScreenFixture(
      duration: Duration(milliseconds: regions.last.endMs),
    );

    testWidgets('names the new pad after its badge', (tester) async {
      final decodePcm = PracticeRegionsScreen.decodePcm;
      PracticeRegionsScreen.decodePcm = (
        _, {
        required sampleRate,
        required durationMs,
      }) async => null;
      addTearDown(() => PracticeRegionsScreen.decodePcm = decodePcm);
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await fixture.pump(
        tester,
        PracticeRegionsScreenFixture.entry(
          songId: 'saved-song',
          grid: grid,
          regions: regions,
        ).copyWith(peaks: const [20, 60, 40]),
      );

      await tester.tap(find.byKey(const ValueKey('play')));
      await fixture.settleAudio(tester);
      fixture.emitPosition(grid.msOfBar(6));
      await fixture.settleAudio(tester);
      await tester.tap(find.byKey(const ValueKey('song-map-key-Chop')));
      await fixture.settleAudio(tester);

      final view = tester.widget<SongMapPads>(find.byType(SongMapPads)).view;
      final sections = view.children();
      expect(sections, hasLength(5));
      for (final (i, section) in sections.indexed) {
        final label = view.sectionLetter(i).label;
        expect(section.name, matches(RegExp('^Part $label 1\$')));
      }
      expect(fixture.savedEntries.last.regions, orderedEquals(view.regions));
    });
  });
}
