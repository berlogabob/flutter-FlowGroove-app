import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  const grid = AudioGrid(bpm: 170);
  const sections = [
    ('Intro 1', 9),
    ('Part B 1', 8),
    ('Chorus 1', 12),
    ('Part D 1', 16),
    ('Part E 1', 8),
    ('Chorus 2', 12),
    ('Part D 2', 16),
    ('Bridge 1', 12),
    ('Bridge 2', 4),
    ('Part D 3', 21),
  ];
  var bar = 0;
  final regions = [
    for (final (index, (name, bars)) in sections.indexed)
      AudioRegion(
        id: 'section-$index',
        name: name,
        section: name,
        startMs: grid.msOfBar(bar),
        endMs: grid.msOfBar(bar += bars),
      ),
  ];
  final fixture = PracticeRegionsScreenFixture(
    duration: Duration(milliseconds: regions.last.endMs),
  );
  final entry =
      PracticeRegionsScreenFixture.entry(
        songId: 'song-a',
        grid: grid,
        regions: regions,
      ).copyWith(
        title: 'Inocente',
        peaks: const [20, 60, 40],
        notes: List.generate(10, (i) => (ms: i * 1000, text: 'Note $i')),
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

  Finder pad(int index) => find.byKey(ValueKey('region-pad-section-$index'));

  void sizePhone(WidgetTester tester, Size physicalSize) {
    tester.view
      ..physicalSize = physicalSize
      ..devicePixelRatio = 3.0
      ..padding = const FakeViewPadding(top: 72, bottom: 72);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  void expectNameSize(WidgetTester tester, Finder name) {
    expect(name.hitTestable(), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(name);
    final style = tester.widget<Text>(name).style!;
    expect(style, MonoPulseTypography.labelLarge.copyWith(color: style.color));
    expect(tester.getRect(name).height, closeTo(paragraph.size.height, 0.001));
    expect(paragraph.didExceedMaxLines, isFalse);
  }

  for (final (phone, physicalSize, theme) in [
    ('P30', const Size(1080, 2340), MonoPulseTheme.theme),
    ('A24', const Size(1260, 2800), MonoPulseTheme.lightTheme),
  ]) {
    testWidgets('$phone shows two columns with full-size pad names', (
      tester,
    ) async {
      sizePhone(tester, physicalSize);
      await fixture.pump(tester, entry, theme: theme);

      final overview = find.byKey(const ValueKey('song-map-overview'));
      final zoom = find.byKey(const ValueKey('song-map-zoom'));
      final bankName = find.text('Sections');
      final keys = [
        for (final label in ['Shift', 'Chop', 'Range'])
          find.byKey(ValueKey('song-map-key-$label')),
      ];
      final notesHeader = find.text('Notes · 10');
      final scrollable = find.descendant(
        of: find.byType(SongMapPads),
        matching: find.byType(Scrollable),
      );
      final gridRect = tester.getRect(scrollable);
      final rects = List.generate(4, (index) => tester.getRect(pad(index)));

      expect(
        tester.getRect(overview).bottom,
        lessThanOrEqualTo(tester.getRect(zoom).top),
      );
      for (final header in [bankName, ...keys]) {
        expect(header.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(zoom).bottom,
          lessThanOrEqualTo(tester.getRect(header).top),
        );
        expect(tester.getRect(header).bottom, lessThanOrEqualTo(gridRect.top));
      }
      expect(notesHeader.hitTestable(), findsOneWidget);
      expect(find.text('Note 0'), findsNothing);
      expect(rects[0].top, rects[1].top);
      expect(rects[2].top, rects[3].top);
      expect(rects[2].top, greaterThanOrEqualTo(rects[0].bottom));
      expect(rects[0].left, rects[2].left);
      expect(rects[1].left, rects[3].left);
      expect(rects[1].left, greaterThanOrEqualTo(rects[0].right));
      for (final (index, rect) in rects.indexed) {
        expect(pad(index).hitTestable(), findsOneWidget);
        expect(rect.top, greaterThanOrEqualTo(gridRect.top));
        expect(rect.bottom, lessThanOrEqualTo(gridRect.bottom));
        expect(rect.bottom, lessThanOrEqualTo(tester.getRect(notesHeader).top));
      }

      final position = tester.state<ScrollableState>(scrollable).position;
      if (phone == 'P30') expect(position.maxScrollExtent, greaterThan(0));
      for (final (index, (label, bars)) in sections.indexed) {
        final tile = pad(index);
        if (tester.getRect(tile).bottom > gridRect.bottom) {
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
        }
        expect(tile.hitTestable(), findsOneWidget);
        final name = find.descendant(of: tile, matching: find.text(label));
        expectNameSize(tester, name);
        final subtitle = find.descendant(
          of: tile,
          matching: find.text('$bars bars'),
        );
        expect(subtitle.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(subtitle).top,
          greaterThanOrEqualTo(tester.getRect(name).bottom),
        );
      }
      expect(tester.getRect(scrollable), gridRect);
      if (phone == 'P30') expect(position.pixels, greaterThan(0));
    });
  }

  testWidgets('P30 keeps a wide ten-character name at the token size', (
    tester,
  ) async {
    const label = 'WWWWWWWWWW';
    sizePhone(tester, const Size(1080, 2340));
    await fixture.pump(
      tester,
      entry.copyWith(
        regions: [
          regions.first.copyWith(name: label, section: label),
          ...regions.skip(1),
        ],
      ),
      theme: MonoPulseTheme.theme,
    );
    expectNameSize(
      tester,
      find.descendant(of: pad(0), matching: find.text(label)),
    );
  });
}
