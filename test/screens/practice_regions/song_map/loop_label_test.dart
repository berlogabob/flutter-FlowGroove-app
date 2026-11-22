import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  const grid = AudioGrid(bpm: 120);
  final regions = [
    for (var section = 0; section < 2; section++)
      for (var part = 0; part < 2; part++)
        AudioRegion(
          id: 'r${section * 2 + part}',
          name: 'Part ${section + 1} ${part + 1}',
          section: 'Section ${section + 1}',
          sectionId: 's$section',
          startMs: grid.msOfBar(1 + (section * 2 + part) * 2),
          endMs: grid.msOfBar(3 + (section * 2 + part) * 2),
        ),
  ];
  final fixture = PracticeRegionsScreenFixture(
    duration: Duration(milliseconds: regions.last.endMs),
  );
  final entry = PracticeRegionsScreenFixture.entry(
    songId: 'saved-song',
    grid: grid,
    regions: regions,
  );

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

  Finder pad(String id) => find.byKey(ValueKey('region-pad-$id'));
  Finder key(String label) => find.byKey(ValueKey('song-map-key-$label'));

  Future<void> press(WidgetTester tester, Finder control) async {
    expect(control.hitTestable(), findsOneWidget);
    await tester.tap(control);
    await fixture.settleAudio(tester);
  }

  testWidgets('loop status names one section pad', (tester) async {
    await pump(tester);
    expect(find.byType(SongMapPads), findsOneWidget);
    await press(tester, pad('r0'));
    expect(find.text('Looping Section 1'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('loop status names the first and last section pads', (
    tester,
  ) async {
    await pump(tester);
    await press(tester, key('Range'));
    await press(tester, pad('r0'));
    await press(tester, pad('r2'));
    expect(find.text('Looping Section 1 → Section 2'), findsOneWidget);
  });

  testWidgets('loop status names one part pad inside a section', (
    tester,
  ) async {
    await pump(tester);
    await press(tester, key('Shift'));
    await press(tester, pad('r0'));
    await press(tester, pad('r0'));
    expect(find.text('Looping Part 1 1'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
  });
}
