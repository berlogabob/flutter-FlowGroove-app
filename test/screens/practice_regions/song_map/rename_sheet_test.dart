import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  const grid = AudioGrid(bpm: 170);
  const sections = [
    ('Intro', 9),
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
      for (var part = 0; part < (index == 2 ? 3 : 1); part++)
        AudioRegion(
          id: 's$index-$part',
          name: index == 2 ? '$name ${String.fromCharCode(97 + part)}' : name,
          section: name,
          startMs: grid.msOfBar(bar),
          endMs: grid.msOfBar(bar += index == 2 ? 4 : bars),
        ),
  ];
  final fixture = PracticeRegionsScreenFixture(
    duration: Duration(milliseconds: regions.last.endMs),
  );
  final entry = PracticeRegionsScreenFixture.entry(
    grid: grid,
    regions: regions,
  ).copyWith(peaks: const [20, 60, 40]);

  Finder pad(int index, [int part = 0]) =>
      find.byKey(ValueKey('region-pad-s$index-$part'));
  Finder inside(Finder parent, String label) => find.descendant(
    of: parent,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == label,
    ),
  );

  for (final (mode, theme) in [
    ('light', MonoPulseTheme.lightTheme),
    ('dark', MonoPulseTheme.theme),
  ]) {
    testWidgets('section rename and repeat move on the $mode phone screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await fixture.pump(tester, entry, theme: theme);
      final picked = pad(4);
      expect(inside(picked, 'Part E 1').hitTestable(), findsOneWidget);
      await tester.longPress(picked);
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      final field = find.descendant(
        of: sheet,
        matching: find.byType(TextField),
      );
      final cancel = inside(sheet, 'Cancel');
      final save = inside(sheet, 'Save');
      expect(tester.widget<TextField>(field).controller!.text, 'Part E');
      final screen =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      final sheetItems = [
        inside(sheet, 'Rename section'),
        inside(sheet, 'Name'),
        field,
        inside(sheet, 'Same as'),
        for (final group in [
          'Intro',
          'Part B',
          'Chorus',
          'Part D',
          'Part E',
          'Bridge',
        ])
          inside(sheet, group),
        inside(sheet, 'Repeats share letter and colour everywhere.'),
        cancel,
        save,
      ];
      for (final item in sheetItems) {
        expect(item.hitTestable(), findsOneWidget);
        final rect = tester.getRect(item);
        expect(rect.left, greaterThanOrEqualTo(screen.left));
        expect(rect.right, lessThanOrEqualTo(screen.right));
        expect(rect.top, greaterThanOrEqualTo(screen.top));
        expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
      }
      expect(
        tester.getRect(field).bottom,
        lessThan(tester.getRect(sheetItems[3]).top),
      );
      expect(tester.getRect(cancel).right, lessThan(tester.getRect(save).left));

      final chorus = inside(sheet, 'Chorus');
      await tester.tap(chorus);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Chorus');
      expect(fixture.savedEntries, isEmpty);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(inside(picked, 'Part E 1'), findsOneWidget);
      expect(fixture.savedEntries, isEmpty);

      await tester.longPress(picked);
      await tester.pumpAndSettle();
      await tester.tap(chorus);
      await tester.tap(save);
      await fixture.settleAudio(tester);

      final lane = find.byKey(const ValueKey('song-map-section-s4-0'));
      Color? badgeColor(int index) {
        final badge = find.byKey(ValueKey('song-map-pad-badge-s$index-0'));
        return (tester.widget<DecoratedBox>(badge).decoration as BoxDecoration)
            .color;
      }

      expect(inside(lane, 'C'), findsOneWidget);
      expect(inside(pad(2), 'Chorus 1'), findsOneWidget);
      expect(inside(picked, 'Chorus 2'), findsOneWidget);
      expect(inside(pad(5), 'Chorus 3'), findsOneWidget);
      expect(badgeColor(4), MonoPulseColors.section8);
      expect(badgeColor(4), badgeColor(2));
      expect(badgeColor(4), badgeColor(5));
      final moved = fixture.savedEntries.last.regions;
      expect(
        moved.map((r) => (r.id, r.startMs, r.endMs)),
        regions.map((r) => (r.id, r.startMs, r.endMs)),
      );
      expect(moved.map((r) => r.section), [
        'Intro',
        'Part B 1',
        'Chorus 1',
        'Chorus 1',
        'Chorus 1',
        'Part D 1',
        'Chorus 2',
        'Chorus 3',
        'Part D 2',
        'Bridge 1',
        'Bridge 2',
        'Part D 3',
      ]);

      await tester.longPress(picked);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Chorus');
      await tester.enterText(field, 'Refrain');
      await tester.tap(save);
      await fixture.settleAudio(tester);

      expect(inside(pad(2), 'Refrain 1'), findsOneWidget);
      expect(inside(picked, 'Refrain 2'), findsOneWidget);
      expect(inside(pad(5), 'Refrain 3'), findsOneWidget);
      expect(inside(lane, 'C'), findsOneWidget);
      expect(
        fixture.savedEntries.last.regions
            .where((r) => r.section == 'Refrain 1')
            .map((r) => r.name),
        ['Refrain 1 a', 'Refrain 1 b', 'Refrain 1 c'],
      );

      await tester.tap(find.byKey(const ValueKey('song-map-key-Shift')));
      await tester.tap(pad(2));
      await tester.pumpAndSettle();
      await tester.longPress(pad(2, 1));
      await tester.pumpAndSettle();
      expect(inside(sheet, 'Region name'), findsOneWidget);
      expect(inside(sheet, 'Same as'), findsNothing);
      await tester.enterText(field, 'Pickup');
      await tester.tap(save);
      await fixture.settleAudio(tester);
      final parts = fixture.savedEntries.last.regions.where(
        (r) => r.section == 'Refrain 1',
      );
      expect(parts.map((r) => r.name), [
        'Refrain 1 a',
        'Pickup',
        'Refrain 1 c',
      ]);
      expect(tester.takeException(), isNull);
    });
  }
}
