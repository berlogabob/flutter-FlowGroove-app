import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

const _grid = AudioGrid(bpm: 170);
final _duration = Duration(milliseconds: _grid.msOfBar(37));

AudioRegion _part(String id, String section, int start, int end) => AudioRegion(
  id: id,
  name: section,
  section: section,
  startMs: _grid.msOfBar(start),
  endMs: _grid.msOfBar(end),
);

Finder _key(String label) => find.byKey(ValueKey('song-map-key-$label'));

void main() {
  final fixture = PracticeRegionsScreenFixture(duration: _duration);
  final regions = [
    _part('intro', 'Intro', 0, 9),
    _part('verse', 'Part B 1', 9, 17),
    _part('chorus-a', 'Chorus 1', 17, 21),
    _part('chorus-b', 'Chorus 1', 21, 25),
    _part('chorus-c', 'Chorus 1', 25, 29),
    _part('outro', 'Outro', 29, 37),
  ];
  final entry = PracticeRegionsScreenFixture.entry(
    songId: 'song-a',
    grid: _grid,
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

  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    bool demo = false,
  }) {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return fixture.pump(tester, entry, theme: theme, demo: demo);
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.tap(_key(label));
    await tester.pumpAndSettle();
  }

  Future<void> openChorus(WidgetTester tester) async {
    await press(tester, 'Shift');
    await tester.tap(find.byKey(const ValueKey('region-pad-chorus-a')));
    await tester.pump();
  }

  Future<void> seekBar(WidgetTester tester, double bar) async {
    final waveform = tester.getRect(
      find.byKey(const ValueKey('song-map-overview-waveform')),
    );
    await tester.tapAt(
      Offset(
        waveform.left +
            waveform.width * _grid.msOfBar(bar) / _duration.inMilliseconds,
        waveform.center.dy,
      ),
    );
    await fixture.settleAudio(tester);
  }

  OutlinedButton keyWidget(WidgetTester tester, String label) =>
      tester.widget<OutlinedButton>(_key(label));

  void expectKeyLayout(WidgetTester tester, List<String> labels) {
    final screen =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    Rect? previous;
    for (final label in labels) {
      final key = _key(label);
      final rect = tester.getRect(key);
      expect(key.hitTestable(), findsOneWidget);
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(screen.contains(rect.topLeft), isTrue);
      expect(rect.right, lessThanOrEqualTo(screen.right));
      expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
      if (previous != null) {
        expect(rect.left, greaterThanOrEqualTo(previous.right));
        expect(rect.top, previous.top);
      }
      previous = rect;
    }
  }

  for (final theme in [MonoPulseTheme.lightTheme, MonoPulseTheme.theme]) {
    testWidgets('Shift opens the Chorus 1 bank in ${theme.brightness.name}', (
      tester,
    ) async {
      await pump(tester, theme: theme);
      expect(find.text('Sections'), findsOneWidget);
      expect(_key('‹ Song'), findsNothing);
      expectKeyLayout(tester, ['Shift', 'Chop', 'Range']);
      final idle = keyWidget(tester, 'Shift').style!;
      final palette = tester.element(_key('Shift')).mp;
      expect(idle.backgroundColor!.resolve({}), palette.surfaceRaised);
      expect(idle.side!.resolve({}), BorderSide(color: palette.borderStrong));

      await press(tester, 'Shift');
      final lit = keyWidget(tester, 'Shift').style!;
      expect(lit.backgroundColor!.resolve({}), MonoPulseColors.accentOrange);
      expect(lit.foregroundColor!.resolve({}), MonoPulseColors.charcoal);
      await tester.tap(find.byKey(const ValueKey('region-pad-chorus-a')));
      await tester.pump();

      final bank = find.byType(SongMapPads);
      expect(find.widgetWithText(SongMapPads, 'C · Chorus 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('region-pad-intro')), findsNothing);
      for (final (index, label) in [
        'Bars 18-21',
        'Bars 22-25',
        'Bars 26-29',
      ].indexed) {
        final pad = find.widgetWithText(InkWell, label);
        expect(pad.hitTestable(), findsOneWidget);
        expect(
          find.descendant(of: pad, matching: find.text('4 bars')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: pad,
            matching: find.text(String.fromCharCode(97 + index)),
          ),
          findsOneWidget,
        );
      }
      expect(tester.widget<SongMapPads>(bank).view.sectionIndex, 2);
      expect(
        keyWidget(tester, 'Shift').style!.backgroundColor!.resolve({}),
        palette.surfaceRaised,
      );
      expectKeyLayout(tester, ['‹ Song', 'Shift', 'Chop', 'Range']);

      await press(tester, '‹ Song');
      expect(find.text('Sections'), findsOneWidget);
      expect(find.byKey(const ValueKey('region-pad-intro')), findsOneWidget);
      expect(_key('‹ Song'), findsNothing);
      expect(fixture.savedEntries, isEmpty);
    });
  }

  testWidgets('Chop snaps to the nearest bar while playing and can undo', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Play'));
    await fixture.settleAudio(tester);
    await seekBar(tester, 32.65);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Tap a pad to edit'), findsNothing);

    await press(tester, 'Chop');
    final updated = fixture.savedEntries.single.regions;
    expect(updated, hasLength(regions.length + 1));
    expect(updated[updated.length - 2].endMs, _grid.msOfBar(33));
    expect(updated.last.startMs, _grid.msOfBar(33));
    expect(updated.last.section, isNot(updated[updated.length - 2].section));
    expect(find.text('Cut at bar 34'), findsOneWidget);
    expect(find.text('bar 34'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(
      keyWidget(tester, 'Chop').style!.backgroundColor!.resolve({}),
      MonoPulseColors.accentOrange,
    );
    expectKeyLayout(tester, ['Shift', 'Chop', 'Range']);
    expect(
      tester
          .widget<SongMapOverview>(find.byType(SongMapOverview))
          .candidateBoundariesMs,
      {_grid.msOfBar(33)},
    );

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await fixture.settleAudio(tester);
    expect(fixture.savedEntries.last.regions, orderedEquals(regions));
    expect(find.text('bar 34'), findsNothing);
  });

  testWidgets(
    'Shift+Chop removes the closest section seam, ignoring part seams',
    (tester) async {
      await pump(tester);
      await seekBar(tester, 21.1);
      await press(tester, 'Shift');
      await press(tester, 'Chop');

      final updated = fixture.savedEntries.single.regions;
      final merged = updated.where((region) => region.section == 'Part B 1');
      expect(merged.first.startMs, _grid.msOfBar(9));
      expect(merged.last.endMs, _grid.msOfBar(29));
      expect(
        merged.map((region) => region.endMs),
        isNot(contains(_grid.msOfBar(17))),
      );
      expect(updated.first, same(regions.first));
      expect(updated.last, same(regions.last));
      expect(find.text('Removed cut at bar 18'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await fixture.settleAudio(tester);
      expect(fixture.savedEntries.last.regions, orderedEquals(regions));
    },
  );

  testWidgets('part zoom chops on the beat and only removes part seams', (
    tester,
  ) async {
    await pump(tester);
    await openChorus(tester);
    final part = find.byKey(const ValueKey('song-map-part-chorus-a'));
    await tester.tap(part);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(part);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('song-map-beats')), findsOneWidget);
    await seekBar(tester, 17.29);
    await press(tester, 'Chop');

    final updated = fixture.savedEntries.single.regions;
    expect(updated, hasLength(regions.length + 1));
    expect(updated[2].endMs, _grid.msOfBar(17.25));
    expect(updated[3].startMs, _grid.msOfBar(17.25));
    expect(updated[3].section, 'Chorus 1');
    expect(updated[4], same(regions[3]));
    expectKeyLayout(tester, ['‹ Song', 'Shift', 'Chop', 'Range']);

    await seekBar(tester, 17.05);
    await press(tester, 'Shift');
    await press(tester, 'Chop');
    final merged = fixture.savedEntries.last.regions;
    expect(
      merged.map((region) => region.toJson()),
      equals(regions.map((region) => region.toJson()).toList()),
    );
    expect(find.text('Removed cut at bar 18'), findsOneWidget);
    await press(tester, '‹ Song');
    expect(find.text('Sections'), findsOneWidget);
  });

  testWidgets('viewers can open the parts bank but have no Chop key', (
    tester,
  ) async {
    await pump(tester, demo: true);
    expect(_key('Chop'), findsNothing);
    await openChorus(tester);
    expect(find.widgetWithText(SongMapPads, 'C · Chorus 1'), findsOneWidget);
    expect(_key('Chop'), findsNothing);
  });

  testWidgets('Range loops the run of pads in the open bank', (tester) async {
    await pump(tester);
    await openChorus(tester);
    await press(tester, 'Range');
    expect(
      keyWidget(tester, 'Range').style!.backgroundColor!.resolve({}),
      MonoPulseColors.accentOrange,
    );
    await tester.tap(find.text('Bars 18-21'));
    await tester.pump();
    await tester.tap(find.text('Bars 26-29'));
    await fixture.settleAudio(tester);
    final bank = tester.widget<SongMapPads>(find.byType(SongMapPads));
    expect(bank.selectedIndices, {0, 1, 2});
    expect(bank.view.sectionIndex, 2);
    expect(
      keyWidget(tester, 'Range').style!.backgroundColor!.resolve({}),
      isNot(MonoPulseColors.accentOrange),
    );
    expect(fixture.savedEntries, isEmpty);
  });
}
