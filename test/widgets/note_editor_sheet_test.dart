import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/widgets/practice/note_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _track = MidiTrackMeta(
  index: 0,
  name: 'Piano',
  channel: 0,
  program: 0,
  detectedRole: MidiRole.keys,
  noteCount: 1,
  minPitch: 60,
  maxPitch: 60,
);
const _note = MidiNote(tick: 0, dur: 120, pitch: 60, vel: 100);

Future<void> _openSheet(
  WidgetTester tester, {
  required void Function(List<int>?) onApply,
  MidiTrackMeta track = _track,
  List<MidiNote> notes = const [_note],
  List<({String name, int startBar, int bars})> sections = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => NoteEditorSheet(
                track: track,
                notes: notes,
                ppq: 480,
                beatsPerBar: 4,
                sections: sections,
                onApply: onApply,
              ),
            ),
            child: const Text('Edit notes'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Edit notes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Apply preserves the original notes without edits', (
    tester,
  ) async {
    final calls = <List<int>?>[];
    await _openSheet(tester, onApply: calls.add);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(calls, [
      [0, 120, 60, 100],
    ]);
    expect(find.byType(NoteEditorSheet), findsNothing);
  });

  testWidgets('tapping C4 step 2 adds a note at tick 240', (tester) async {
    final semantics = tester.ensureSemantics();
    final calls = <List<int>?>[];
    final notes = [_note];
    await _openSheet(tester, notes: notes, onApply: calls.add);
    final cell = find.bySemanticsLabel('C4 step 2');
    expect(tester.getSemantics(cell), isSemantics(isSelected: false));

    await tester.tap(cell);
    await tester.pump();
    expect(tester.getSemantics(cell), isSemantics(isSelected: true));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(calls.single, hasLength(8));
    expect(calls.single, [0, 120, 60, 100, 240, 120, 60, 100]);
    expect(notes, [_note]);
    semantics.dispose();
  });

  testWidgets('Reset to file applies null and closes the sheet', (
    tester,
  ) async {
    final calls = <List<int>?>[];
    await _openSheet(tester, onApply: calls.add);

    await tester.tap(find.text('Reset to file'));
    await tester.pumpAndSettle();

    expect(calls, [null]);
    expect(find.byType(NoteEditorSheet), findsNothing);
  });

  testWidgets('drum kick lane adds pitch 36 using the effective role', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final calls = <List<int>?>[];
    await _openSheet(
      tester,
      track: _track.copyWith(roleOverride: MidiRole.drums),
      notes: const [],
      onApply: calls.add,
    );

    await tester.tap(find.bySemanticsLabel('Kick step 0'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(calls.single, [0, 120, 36, 100]);
    semantics.dispose();
  });

  testWidgets('bar navigation shows sections and keeps the initial bar count', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final calls = <List<int>?>[];
    await _openSheet(
      tester,
      notes: const [MidiNote(tick: 1920, dur: 1920, pitch: 60, vel: 100)],
      sections: const [
        (name: 'Intro', startBar: 0, bars: 1),
        (name: 'Verse', startBar: 1, bars: 1),
      ],
      onApply: calls.add,
    );
    expect(find.text('Bar 1 of 2'), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Previous bar',
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Next bar'));
    await tester.pump();
    expect(find.text('Bar 2 of 2'), findsOneWidget);
    expect(find.text('Verse'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Next bar',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.bySemanticsLabel('C4 step 0'));
    await tester.pump();
    expect(find.text('Bar 2 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous bar'));
    await tester.pump();
    expect(find.text('Intro'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(calls.single, isEmpty);
    semantics.dispose();
  });

  testWidgets('Apply rejects more than 40000 flat values', (tester) async {
    final calls = <List<int>?>[];
    await _openSheet(
      tester,
      notes: List.filled(10001, _note),
      onApply: calls.add,
    );

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(find.text('Too many notes to save'), findsOneWidget);
    expect(find.byType(NoteEditorSheet), findsOneWidget);
  });
}
