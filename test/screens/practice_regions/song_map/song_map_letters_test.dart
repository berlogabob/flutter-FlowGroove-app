import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_letters.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

AudioRegion _region(String name, int index) => AudioRegion(
  id: 'section-$index',
  name: name,
  startMs: index * 1000,
  endMs: (index + 1) * 1000,
);

void main() {
  const names = [
    'Intro 1',
    'Part B 1',
    'Chorus 1',
    'Part D 1',
    'Part E 1',
    'Chorus 2',
    'Part D 2',
    'Bridge 1',
    'Bridge 2',
    'Part D 3',
  ];
  const palette = [
    MonoPulseColors.section1,
    MonoPulseColors.section5,
    MonoPulseColors.section8,
    MonoPulseColors.section3,
    MonoPulseColors.section11,
    MonoPulseColors.section7,
    MonoPulseColors.section4,
    MonoPulseColors.section10,
  ];

  test('Inocente groups numbered repeats by first appearance', () {
    final sections = [
      for (final (index, name) in names.indexed) _region(name, index),
    ];
    final letters = SongMapLetters(sections);
    expect(
      [for (final (i, _) in sections.indexed) letters[i].label].join(),
      'ABCDECDFFD',
    );
    expect(
      [for (final (i, _) in sections.indexed) letters[i].color],
      [
        for (final i in [0, 1, 2, 3, 4, 2, 3, 5, 5, 3]) palette[i],
      ],
    );
  });

  test('empty names get separate groups and the badge palette repeats', () {
    final letters = SongMapLetters(List.generate(9, (i) => _region('', i)));
    expect([for (var i = 0; i < 9; i++) letters[i].label].join(), 'ABCDEFGHI');
    expect(
      [for (var i = 0; i < 9; i++) letters[i].color],
      [...palette, palette.first],
    );
    expect(
      [for (var i = 0; i < 9; i++) letters[i].textColor],
      [
        for (var i = 0; i < 9; i++)
          if (const {0, 3, 6, 8}.contains(i))
            MonoPulseColors.textHighEmphasis
          else
            MonoPulseColors.charcoal,
      ],
    );
  });

  test(
    'linked parts inherit their parent group even when their names are empty',
    () {
      final letters = SongMapLetters([
        _region('Part A 1', 0),
        _region('Pickup', 1).copyWith(sectionId: 'c1', section: 'Chorus 1'),
        _region('', 2).copyWith(sectionId: 'c1'),
        _region('Ending', 3).copyWith(sectionId: 'c2', section: ' CHORUS\t2 '),
      ]);
      expect([for (var i = 0; i < 4; i++) letters[i].label].join(), 'ABBB');
      expect(letters[1].color, letters[2].color);
      expect(letters[1].color, letters[3].color);
    },
  );

  group('full practice screen', () {
    const grid = AudioGrid(bpm: 170);
    const bars = [9, 8, 12, 16, 8, 12, 16, 12, 4, 21];
    var bar = 0;
    final regions = [
      for (final (i, name) in names.indexed)
        for (var part = 0; part < (i == 2 ? 3 : 1); part++)
          AudioRegion(
            id: i == 2 ? 'section-$i-$part' : 'section-$i',
            name: i == 2 ? '$name ${String.fromCharCode(97 + part)}' : name,
            section: name,
            startMs: grid.msOfBar(bar),
            endMs: grid.msOfBar(bar += i == 2 ? 4 : bars[i]),
          ),
    ];
    final fixture = PracticeRegionsScreenFixture(
      duration: Duration(milliseconds: regions.last.endMs),
    );
    final entry = PracticeRegionsScreenFixture.entry(
      grid: grid,
      regions: regions,
    ).copyWith(peaks: const [20, 60, 40]);

    for (final (mode, theme) in [
      ('light', MonoPulseTheme.lightTheme),
      ('dark', MonoPulseTheme.theme),
    ]) {
      testWidgets('repeat and part colours match across the $mode screen', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await fixture.pump(tester, entry, theme: theme);

        final chorus1Lane = find.byKey(
          const ValueKey('song-map-section-section-2-0'),
        );
        final chorus2Lane = find.byKey(
          const ValueKey('song-map-section-section-5'),
        );
        final chorus2Badge = find.byKey(
          const ValueKey('song-map-pad-badge-section-5'),
        );
        final chorus2Pad = find.byKey(const ValueKey('region-pad-section-5'));

        Iterable<String?> textIn(Finder target) => tester
            .widgetList<Text>(
              find.descendant(of: target, matching: find.byType(Text)),
            )
            .map((text) => text.data);
        Color? blockColor(Finder target) =>
            (tester.widget<Container>(target).decoration! as BoxDecoration)
                .color;
        Color? badgeColor(Finder target) =>
            (tester.widget<DecoratedBox>(target).decoration as BoxDecoration)
                .color;

        expect(textIn(chorus1Lane), ['C']);
        expect(textIn(chorus2Lane), ['C']);
        expect(textIn(chorus2Badge), ['C']);
        Color laneTint(Color color, Finder target) => Color.alphaBlend(
          color.withValues(alpha: 0.35),
          tester.element(target).mp.surfaceRaised,
        );
        expect(
          blockColor(chorus2Lane),
          laneTint(MonoPulseColors.section8, chorus2Lane),
        );
        expect(blockColor(chorus2Lane), blockColor(chorus1Lane));
        expect(
          blockColor(chorus2Lane),
          laneTint(badgeColor(chorus2Badge)!, chorus2Lane),
        );
        expect(
          find.descendant(
            of: chorus2Pad,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ColoredBox &&
                  widget.color == badgeColor(chorus2Badge),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SongMapOverview),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ColoredBox &&
                  widget.color ==
                      MonoPulseColors.section8.withValues(alpha: 0.25),
            ),
          ),
          findsNWidgets(2),
        );
        expect(chorus2Pad.hitTestable(), findsOneWidget);
        final padName = find.descendant(
          of: chorus2Pad,
          matching: find.text('Chorus 2'),
        );
        expect(
          tester.renderObject<RenderParagraph>(padName).didExceedMaxLines,
          isFalse,
        );
        expect(
          tester.getRect(chorus2Badge).right,
          lessThan(tester.getRect(padName).left),
        );
        expect(
          tester.getRect(chorus2Pad).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(SongMapTransport)).top),
        );

        await tester.tap(chorus1Lane);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(chorus1Lane);
        await tester.pumpAndSettle();
        final partBadge = find.byKey(
          const ValueKey('song-map-pad-badge-section-2-1'),
        );
        final partLane = find.byKey(
          const ValueKey('song-map-part-section-2-1'),
        );
        expect(partBadge.hitTestable(), findsOneWidget);
        expect(textIn(partBadge), ['b']);
        expect(textIn(partLane), ['b', '4 bars']);
        expect(badgeColor(partBadge), MonoPulseColors.section8);
        expect(
          blockColor(partLane),
          laneTint(badgeColor(partBadge)!, partLane),
        );
        final chorusTint = laneTint(MonoPulseColors.section8, chorus2Lane);
        final chorusBand = MonoPulseColors.section8.withValues(alpha: 0.25);
        expect(
          find.descendant(
            of: find.byType(SongMapOverview),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ColoredBox && widget.color == chorusBand ||
                  widget is Container &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration! as BoxDecoration).color == chorusTint,
            ),
          ),
          findsNWidgets(4),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
