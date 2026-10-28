import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_setup_wizard.dart';
import 'package:flowgroove/services/audio/audio_markers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PracticeSetupResult? result;
  var returned = false;
  var id = 0;
  final previews = <AudioGrid>[];

  Future<void> open(
    WidgetTester tester, {
    List<FileMarker> markers = const [],
    List<String> songSectionNames = const [],
  }) async {
    result = null;
    returned = false;
    id = 0;
    previews.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPracticeSetupWizard(
                  context,
                  durationMs: 50000,
                  detectGrid: () async => (bpm: 120.0, firstDownbeatMs: 250),
                  fileMarkers: () async => markers,
                  previewGrid: (grid) async {
                    previews.add(grid);
                  },
                  songSectionNames: songSectionNames,
                  newId: () => 'region-${id++}',
                );
                returned = true;
              },
              child: const Text('Open setup'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open setup'));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
  }

  testWidgets('file markers are preselected and keep their names on Finish', (
    tester,
  ) async {
    await open(
      tester,
      markers: const [
        FileMarker(ms: 0, name: 'Intro'),
        FileMarker(ms: 10000, name: 'Verse'),
        FileMarker(ms: 30000, name: 'Chorus'),
      ],
    );
    expect(find.text('We hear 120.0 BPM'), findsOneWidget);
    expect(find.text('First downbeat at 0:00.250'), findsOneWidget);
    await next(tester);
    final source = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Use 3 markers from the file'),
    );
    expect(source.selected, isTrue);
    await next(tester);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!.text),
      ['Intro', 'Verse', 'Chorus'],
    );
    await finish(tester);
    expect(result!.regions, hasLength(3));
    expect(result!.regions!.map((region) => region.name), [
      'Intro',
      'Verse',
      'Chorus',
    ]);
    expect(result!.grid!.bpm, 120);
    expect(result!.grid!.offsetMs, 250);
    expect(result!.markByEar, isFalse);
  });

  testWidgets(
    'without markers defaults to every eight bars from the downbeat',
    (tester) async {
      await open(tester);
      await next(tester);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Every 8 bars'))
            .selected,
        isTrue,
      );
      await next(tester);
      await finish(tester);
      expect(result!.regions!.map((region) => region.startMs), [
        0,
        250,
        16250,
        32250,
        48250,
      ]);
      expect(result!.regions!.last.endMs, 50000);
      expect(result!.grid!.bpm, 120);
    },
  );

  testWidgets('Skip returns null', (tester) async {
    await open(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
  });

  testWidgets('no steady tempo allows marking by ear without regions', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('No steady tempo'));
    await tester.pump();
    await next(tester);
    expect(find.text('Every 8 bars'), findsNothing);
    expect(
      tester
          .widget<ListTile>(
            find.widgetWithText(ListTile, "I'll mark them by ear"),
          )
          .selected,
      isTrue,
    );
    await next(tester);
    await finish(tester);
    expect(result!.grid, isNull);
    expect(result!.regions, isNull);
    expect(result!.markByEar, isTrue);
  });

  testWidgets('Adjust updates preview and song names fill fields in order', (
    tester,
  ) async {
    await open(tester, songSectionNames: ['Opening', 'Theme']);
    await tester.tap(find.text('Adjust'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase 120.0 BPM'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase Downbeat 0:00.250'));
    await tester.pump();
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(previews.single.bpm, 120.5);
    expect(previews.single.offsetMs, 260);
    await next(tester);
    await next(tester);
    await tester.tap(find.text('Suggest names'));
    await tester.pump();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller!.text, 'Opening');
    expect(fields[1].controller!.text, 'Theme');
    await finish(tester);
    expect(result!.regions!.first.name, 'Opening');
  });
}
