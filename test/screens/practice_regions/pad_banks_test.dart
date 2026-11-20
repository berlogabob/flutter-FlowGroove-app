import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/pad_banks.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart'
    show colorForName;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

AudioRegion part(
  int i,
  String? section,
  String letter, {
  bool skip = false,
  String? sectionId,
}) => AudioRegion(
  id: '$i',
  name: section == null ? letter : '$section $letter',
  section: section,
  sectionId: sectionId,
  startMs: i * 2000,
  endMs: (i + 1) * 2000,
  skip: skip,
);

void main() {
  final regions = [
    part(0, 'Chorus 1', 'a'),
    part(1, 'Chorus 1', 'b'),
    part(2, 'Verse 1', 'c'),
    part(3, 'Chorus 2', 'd'),
    part(4, 'Chorus 2', 'e'),
  ];
  final selections = <(int, int)?>[];
  final edits = <int>[];
  final renames = <String>[];
  Finder bank(int i) => find.byKey(ValueKey('region-bank-$i'));
  Finder pad(int i) => find.byKey(ValueKey('region-pad-$i'));

  Future<void> pump(
    WidgetTester tester, {
    List<AudioRegion>? parts,
    bool editing = false,
    bool playing = false,
    int positionMs = 0,
    (int, int)? selection,
    AudioGrid? grid,
    Map<String, Color> sectionColors = const {},
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PadBanks(
          regions: parts ?? regions,
          colorForName: colorForName,
          sectionColors: sectionColors,
          grid: grid,
          editing: editing,
          playing: playing,
          positionMs: positionMs,
          selection: selection,
          onSelect: selections.add,
          onEdit: edits.add,
          onRenameSection: renames.add,
        ),
      ),
    ),
  );

  setUp(() {
    selections.clear();
    edits.clear();
    renames.clear();
  });

  testWidgets('one bank per occurrence, repeats share base colors', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Chorus 1'), findsOneWidget);
    expect(find.text('Verse 1'), findsOneWidget);
    expect(find.text('Chorus 2'), findsOneWidget);
    expect(bank(1), findsNothing);
    Color? color(int i) => tester
        .widget<Material>(
          find.descendant(of: bank(i), matching: find.byType(Material)),
        )
        .color;
    expect(color(0), colorForName('Chorus'));
    expect(color(3), color(0));
    expect(color(2), isNot(color(0)));
    expect(pad(0), findsOneWidget);
    expect(pad(1), findsOneWidget);
    expect(pad(2), findsNothing);
  });

  testWidgets('song map color takes precedence', (tester) async {
    await pump(
      tester,
      parts: [part(0, 'Chorus 1', 'a', sectionId: 'chorus')],
      sectionColors: {'chorus': Colors.purple},
    );
    final material = tester.widget<Material>(
      find.descendant(of: bank(0), matching: find.byType(Material)),
    );
    expect(material.color, Colors.purple);
  });

  testWidgets(
    'song map color is shared across numbered occurrences of a base',
    (tester) async {
      await pump(
        tester,
        parts: [
          part(0, 'Chorus 1', 'a', sectionId: 'first'),
          part(1, 'Verse 1', 'b'),
          part(2, 'Chorus 2', 'c', sectionId: 'second'),
        ],
        sectionColors: {'first': Colors.purple, 'second': Colors.green},
      );
      for (final i in [0, 2]) {
        final material = tester.widget<Material>(
          find.descendant(of: bank(i), matching: find.byType(Material)),
        );
        expect(material.color, Colors.purple);
      }
      await tester.tap(bank(2));
      await tester.pump();
      final material = tester.widget<Material>(
        find.descendant(of: pad(2), matching: find.byType(Material)),
      );
      expect(material.color, Colors.purple);
    },
  );

  testWidgets(
    'bank tap selects its full original range and displays its parts',
    (tester) async {
      await pump(tester, grid: const AudioGrid(bpm: 120));
      await tester.tap(bank(3));
      await tester.pump();
      expect(selections, [(3, 4)]);
      expect(pad(0), findsNothing);
      expect(pad(3), findsOneWidget);
      expect(pad(4), findsOneWidget);
      expect(find.text('d'), findsOneWidget);
      expect(find.text('1 bars'), findsNWidgets(2));
      expect(tester.getSize(pad(3)).height, 88);
    },
  );

  for (final reverse in [false, true]) {
    testWidgets('hold + tap banks selects combined range (reverse: $reverse)', (
      tester,
    ) async {
      await pump(tester);
      final first = await tester.startGesture(
        tester.getCenter(bank(reverse ? 3 : 0)),
        pointer: 1,
      );
      final second = await tester.startGesture(
        tester.getCenter(bank(reverse ? 0 : 3)),
        pointer: 2,
      );
      // Both fingers are down without waiting for a long press.
      expect(selections, [(0, 4)]);
      await second.up();
      await first.up();
      await tester.pump();
      expect(selections, [(0, 4)]);
    });
  }

  testWidgets('legacy regions have no bank row and keep the old pads', (
    tester,
  ) async {
    await pump(tester, parts: [part(0, null, 'Intro'), part(1, null, 'Verse')]);
    expect(find.byKey(const ValueKey('pad-bank-row')), findsNothing);
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Verse'), findsOneWidget);
    expect(tester.getSize(pad(0)).height, 56);
    await tester.tap(pad(1));
    expect(selections, [(1, 1)]);
  });

  testWidgets('follows playhead only while playing without selection', (
    tester,
  ) async {
    await pump(tester, playing: true, positionMs: 6500);
    expect(pad(3), findsOneWidget);
    await pump(tester, playing: true, positionMs: 1000, selection: (3, 4));
    expect(pad(3), findsOneWidget);
    await pump(tester, positionMs: 1000);
    expect(pad(3), findsOneWidget);
    await pump(tester, playing: true, positionMs: 1000);
    expect(pad(0), findsOneWidget);
  });

  testWidgets(
    'Shift long press renames the base and pad tap edits original index',
    (tester) async {
      await pump(tester, editing: true);
      await tester.longPress(bank(3));
      expect(renames, ['Chorus']);
      expect(selections, isEmpty);
      await tester.tap(bank(3));
      await tester.pump();
      await tester.tap(pad(4));
      expect(edits, [4]);
    },
  );

  testWidgets(
    'skipped parts are hidden unless editing and do not merge occurrences',
    (tester) async {
      final parts = [
        part(0, 'Chorus 1', 'a'),
        part(1, 'Verse 1', 'b', skip: true),
        part(2, 'Chorus 1', 'c'),
      ];
      await pump(tester, parts: parts);
      expect(bank(1), findsNothing);
      expect(find.text('Chorus 1'), findsNWidgets(2));
      await tester.tap(bank(2));
      expect(selections, [(2, 2)]);
      await pump(tester, parts: parts, editing: true);
      expect(bank(1), findsOneWidget);
      await tester.tap(bank(1));
      await tester.pump();
      expect(pad(1), findsOneWidget);
    },
  );

  testWidgets('hidden sections alone do not enable banks', (tester) async {
    await pump(
      tester,
      parts: [part(0, 'Intro 1', 'a', skip: true), part(1, null, 'Verse')],
    );
    expect(find.byKey(const ValueKey('pad-bank-row')), findsNothing);
    expect(pad(0), findsNothing);
    expect(pad(1), findsOneWidget);
  });

  testWidgets('part duration rounds to quarter bars', (tester) async {
    await pump(
      tester,
      parts: [
        const AudioRegion(
          id: '0',
          name: 'Chorus 1 a',
          section: 'Chorus 1',
          startMs: 0,
          endMs: 4600,
        ),
      ],
      grid: const AudioGrid(bpm: 120),
    );
    expect(find.text('a'), findsOneWidget);
    expect(find.text('2.25 bars'), findsOneWidget);
  });

  testWidgets(
    'pad hold + tap and long press still extend original region ranges',
    (tester) async {
      await pump(tester, selection: (0, 0));
      final first = await tester.startGesture(
        tester.getCenter(pad(0)),
        pointer: 1,
      );
      await tester.tap(pad(1), pointer: 2);
      await first.up();
      await tester.pump();
      expect(selections, [(0, 1)]);
      selections.clear();
      await tester.longPress(pad(1));
      expect(selections, [(0, 1)]);
    },
  );
}
