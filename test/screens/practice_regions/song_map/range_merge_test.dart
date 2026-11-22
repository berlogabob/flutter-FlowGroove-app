import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

Finder _key(String label) => find.byKey(ValueKey('song-map-key-$label'));
Finder _pad(int index) => find.byKey(ValueKey('region-pad-r$index'));

void main() {
  const grid = AudioGrid(bpm: 120);
  const names = ['Intro', 'Verse', 'Chorus', 'Bridge', 'Solo', 'Outro'];
  final regions = [
    for (final (index, name) in names.indexed)
      AudioRegion(
        id: 'r$index',
        name: '$name a',
        section: name,
        sectionId: 's$index',
        startMs: index == 0 ? 0 : grid.msOfBar(1 + (index - 1) * 4),
        endMs: grid.msOfBar(1 + index * 4),
      ),
  ];
  final fixture = PracticeRegionsScreenFixture(
    duration: Duration(milliseconds: regions.last.endMs),
  );
  final entry = PracticeRegionsScreenFixture.entry(
    songId: 'saved-song',
    grid: grid,
    regions: regions,
  ).copyWith(peaks: const [20, 60, 40]);

  setUp(() {
    final decodePcm = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm = (
      _, {
      required sampleRate,
      required durationMs,
    }) async => null;
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodePcm);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await fixture.pump(tester, entry);
  }

  SongMapPads bank(WidgetTester tester) =>
      tester.widget<SongMapPads>(find.byType(SongMapPads));

  Future<void> press(WidgetTester tester, Finder control) async {
    expect(control.hitTestable(), findsOneWidget);
    await tester.tap(control);
    await fixture.settleAudio(tester);
  }

  testWidgets('Shift + Chop merges the selected range and undoes in one step', (
    tester,
  ) async {
    await pump(tester);
    expect(bank(tester).view.children(), hasLength(6));
    final letter = bank(tester).view.sectionLetter(1);
    final shift = _key('Shift');
    final idleColor = tester
        .widget<OutlinedButton>(shift)
        .style!
        .backgroundColor!
        .resolve({});

    await press(tester, _key('Range'));
    await press(tester, _pad(1));
    await press(tester, _pad(3));
    expect(bank(tester).selectedIndices, {1, 2, 3});
    await press(tester, shift);
    await press(tester, _key('Chop'));

    final merged = bank(tester);
    final pads = merged.view.children();
    expect(pads.map((pad) => pad.id), ['r0', 'r1', 'r4', 'r5']);
    expect(pads[1].startMs, regions[1].startMs);
    expect(pads[1].endMs, regions[3].endMs);
    expect(pads[1].name, 'Verse');
    expect(pads[1].sectionId, 's1');
    expect(merged.view.sectionLetter(1).label, letter.label);
    expect(merged.view.sectionLetter(1).color, letter.color);
    expect(merged.selectedIndices, {1});
    expect(
      tester.widget<OutlinedButton>(shift).style!.backgroundColor!.resolve({}),
      idleColor,
    );
    final saved = fixture.savedEntries.single.regions;
    expect(saved, orderedEquals(merged.view.regions));
    final rebuilt = saved.where((region) => region.sectionId == 's1');
    expect(rebuilt.first.startMs, regions[1].startMs);
    expect(rebuilt.last.endMs, regions[3].endMs);
    expect(saved.map((region) => region.sectionId).toSet(), {
      's0',
      's1',
      's4',
      's5',
    });

    await press(tester, find.widgetWithText(SnackBarAction, 'Undo'));
    expect(bank(tester).view.children(), hasLength(6));
    expect(bank(tester).view.regions, orderedEquals(regions));
    expect(fixture.savedEntries, hasLength(2));
    expect(fixture.savedEntries.last.regions, orderedEquals(regions));
  });

  testWidgets('Shift + Chop removes the nearest boundary for a single pad', (
    tester,
  ) async {
    await pump(tester);
    await press(tester, _pad(3));
    expect(bank(tester).selectedIndices, {3});
    await press(tester, _key('Shift'));
    await press(tester, _key('Chop'));

    final pads = bank(tester).view.children();
    expect(pads.map((pad) => pad.id), ['r0', 'r1', 'r2', 'r4', 'r5']);
    expect(pads[2].startMs, regions[2].startMs);
    expect(pads[2].endMs, regions[3].endMs);
    expect(fixture.savedEntries, hasLength(1));
  });

  testWidgets('a one bar pad has a singular subtitle', (tester) async {
    await pump(tester);
    expect(
      find.descendant(of: _pad(0), matching: find.text('1 bar')),
      findsOneWidget,
    );
  });
}
