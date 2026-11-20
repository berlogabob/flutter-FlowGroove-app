import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const verseA = AudioRegion(
    id: 'verse-a',
    name: 'Verse a',
    startMs: 0,
    endMs: 4000,
    section: 'Verse',
  );
  const verseB = AudioRegion(
    id: 'verse-b',
    name: 'Verse b',
    startMs: 4000,
    endMs: 8000,
    section: 'Verse',
  );
  const chorus = AudioRegion(
    id: 'chorus-a',
    name: 'Chorus a',
    startMs: 8000,
    endMs: 12000,
    section: 'Chorus',
  );
  const durationMs = 13000;

  late SongMapView view;
  setUp(() {
    view = SongMapView(
      regions: const [verseA, verseB, chorus],
      durationMs: durationMs,
      grid: const AudioGrid(bpm: 120, beatsPerBar: 3, offsetMs: 250),
    );
    addTearDown(view.dispose);
  });

  test('zoom changes the viewport and the pad hierarchy', () {
    expect(view.level, SongMapZoom.song);
    expect(view.viewport, (startMs: 0, endMs: durationMs));
    expect(view.children().map((r) => r.name), ['Verse', 'Chorus']);
    expect(view.children().first.lengthMs, 8000);

    view.zoomIn(0);
    expect(view.level, SongMapZoom.section);
    expect(view.sectionIndex, 0);
    expect(view.partIndex, isNull);
    expect(view.viewport, (startMs: 0, endMs: 9500));
    expect(view.children(), [verseA, verseB]);

    view.zoomIn(1);
    expect(view.level, SongMapZoom.part);
    expect(view.partIndex, 1);
    expect(view.viewport, (startMs: 2500, endMs: 9500));
    expect(view.children(), [verseA, verseB]);

    view.zoomOut();
    expect(view.level, SongMapZoom.section);
    expect(view.sectionIndex, 0);
    expect(view.partIndex, isNull);
    view.zoomOut();
    expect(view.level, SongMapZoom.song);
    expect(view.sectionIndex, isNull);
  });

  test('coordinates use the viewport and snapping uses the downbeat', () {
    expect(view.snapMs(4310), 4310);
    view.zoomIn(0);
    expect(view.snapMs(4310), 4750);
    expect(view.snapMs(-1000), 0);
    view.zoomIn(1);
    expect(view.snapMs(4310), 4250);
    expect(view.snapMs(16000), durationMs);
    expect(view.msToX(view.startMs, 350), 0);
    expect(view.msToX(view.endMs, 350), 350);
    expect(view.msToX(6000, 350), 175);
    expect(view.xToMs(175, 350), 6000);
    expect(view.msToX(1500, 350), closeTo(-50, 1e-9));
    expect(view.xToMs(5, 0), view.startMs);
  });

  test('navigation stays at its level and notifies on changes only', () {
    var notifications = 0;
    view
      ..addListener(() => notifications++)
      ..next()
      ..previous()
      ..zoomOut()
      ..zoomIn(-1)
      ..zoomIn(2);
    expect(notifications, 0);

    view
      ..zoomIn(0)
      ..next()
      ..next();
    expect(view.sectionIndex, 1);
    expect(view.viewport, (startMs: 6500, endMs: durationMs));
    view
      ..previous()
      ..previous();
    expect(view.sectionIndex, 0);
    expect(notifications, 3);

    view
      ..zoomIn(0)
      ..previous()
      ..next()
      ..next()
      ..zoomIn(0);
    expect(view.level, SongMapZoom.part);
    expect(view.sectionIndex, 0);
    expect(view.partIndex, 1);
    expect(notifications, 5);
    view.previous();
    expect(view.partIndex, 0);
    expect(notifications, 6);
  });

  test('linked occurrences, skipped regions and legacy pads keep order', () {
    final map = SongMapView(
      regions: [
        verseA.copyWith(sectionId: 'first'),
        verseB.copyWith(sectionId: 'second'),
        chorus.copyWith(skip: true),
        const AudioRegion(id: 'end', name: 'End', startMs: 12000, endMs: 13000),
      ],
      durationMs: durationMs,
    );
    addTearDown(map.dispose);

    expect(map.children().map((r) => r.id), ['verse-a', 'verse-b', 'end']);
    map.zoomIn(1);
    expect(map.children().single.id, 'verse-b');
    expect(map.viewport, (startMs: 4000, endMs: 8000));
    expect(map.snapMs(4310), 4310);
  });

  test('empty audio has a zero-width span', () {
    final empty = SongMapView(regions: const [], durationMs: 0);
    addTearDown(empty.dispose);
    empty.zoomIn(0);
    expect(empty.level, SongMapZoom.song);
    expect(empty.children(), isEmpty);
    expect(empty.msToX(10, 100), 0);
    expect(empty.xToMs(10, 100), 0);
  });
}
