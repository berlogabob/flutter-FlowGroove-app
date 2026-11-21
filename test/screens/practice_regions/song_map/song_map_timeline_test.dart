import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_view.dart';
import 'package:flowgroove/widgets/audio/waveform_painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late SongMapView view;
  final parts = find.byKey(const ValueKey('song-map-parts'));
  final beats = find.byKey(const ValueKey('song-map-beats'));

  setUp(() {
    view = SongMapView(
      durationMs: 24000,
      grid: const AudioGrid(bpm: 120),
      regions: const [
        AudioRegion(id: 'intro', name: 'Intro', startMs: 0, endMs: 8000),
        AudioRegion(
          id: 'chorus-a',
          name: 'Chorus 1 a',
          section: 'Chorus 1',
          startMs: 8000,
          endMs: 12000,
        ),
        AudioRegion(
          id: 'chorus-b',
          name: 'Chorus 1 b',
          section: 'Chorus 1',
          startMs: 12000,
          endMs: 16000,
        ),
        AudioRegion(
          id: 'repeat',
          name: 'Chorus 2 a',
          section: 'Chorus 2',
          startMs: 16000,
          endMs: 24000,
        ),
      ],
    );
    addTearDown(view.dispose);
  });

  Future<void> pumpTimeline(WidgetTester tester, SongMapTimeline timeline) =>
      tester.pumpWidget(
        MaterialApp(
          home: Center(child: SizedBox(width: 384, child: timeline)),
        ),
      );

  Future<void> doubleTap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'song level hides parts and double-tapping a section shows them',
    (tester) async {
      await pumpTimeline(
        tester,
        SongMapTimeline(
          view: view,
          peaks: const [30, 60, 90],
          positionMs: 9000,
        ),
      );
      expect(parts, findsNothing);
      expect(beats, findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is WaveformPainter,
        ),
        findsOneWidget,
      );

      final chorus1 = find.byKey(const ValueKey('song-map-section-chorus-a'));
      final chorus2 = find.byKey(const ValueKey('song-map-section-repeat'));

      Color? blockColor(Finder finder) {
        final block = tester.widget<Container>(finder);
        return (block.decoration! as BoxDecoration).color;
      }

      expect(blockColor(chorus1), blockColor(chorus2));
      for (final block in [chorus1, chorus2]) {
        expect(
          find.descendant(of: block, matching: find.text('B')),
          findsOneWidget,
        );
      }

      await doubleTap(tester, chorus1);
      expect(view.level, SongMapZoom.section);
      expect(view.sectionIndex, 1);
      expect(parts, findsOneWidget);
      expect(
        find.descendant(of: parts, matching: find.text('a')),
        findsOneWidget,
      );
      expect(beats, findsNothing);

      await doubleTap(
        tester,
        find.descendant(of: parts, matching: find.text('b')),
      );
      expect(view.level, SongMapZoom.part);
      expect(view.partIndex, 1);
      expect(beats, findsOneWidget);

      final center = tester.getCenter(parts);
      final first = await tester.startGesture(
        center.translate(-20, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center.translate(20, 0),
        pointer: 2,
      );
      await first.moveBy(const Offset(-30, 0));
      await second.moveBy(const Offset(30, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(view.level, SongMapZoom.section);
      expect(beats, findsNothing);
    },
  );

  testWidgets('narrow and wide section blocks both show only their letter', (
    tester,
  ) async {
    final labelView = SongMapView(
      durationMs: 16000,
      regions: const [
        AudioRegion(
          id: 'intro',
          name: 'Intro 1',
          section: 'Intro 1',
          startMs: 0,
          endMs: 4000,
        ),
        AudioRegion(
          id: 'chorus',
          name: 'Chorus 1',
          section: 'Chorus 1',
          startMs: 4000,
          endMs: 16000,
        ),
      ],
    );
    addTearDown(labelView.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 160, child: SongMapTimeline(view: labelView)),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('Intro 1'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Chorus 1'), findsNothing);
  });

  testWidgets(
    'boundary taps report the file-relative seam at both zoom levels',
    (tester) async {
      final tapped = <int>[];
      final semantics = tester.ensureSemantics();
      await pumpTimeline(
        tester,
        SongMapTimeline(
          view: view,
          candidateBoundariesMs: const {8000},
          selectedBoundaryMs: 12000,
          onBoundaryTap: tapped.add,
        ),
      );

      final candidate = find.bySemanticsLabel('Boundary at 8000 ms');
      await tester.tap(candidate);
      await tester.pumpAndSettle();

      view.zoomIn(1);
      await tester.pumpAndSettle();
      final selected = find.bySemanticsLabel('Boundary at 12000 ms');
      await tester.tap(selected);
      await tester.pump(kDoubleTapTimeout);

      semantics.dispose();
      expect(tapped, [8000, 12000]);
    },
  );
}
