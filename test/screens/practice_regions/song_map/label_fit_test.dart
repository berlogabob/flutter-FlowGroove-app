import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

void main() {
  testWidgets('long section name uses its letter when it does not fit', (
    tester,
  ) async {
    final view = SongMapView(
      durationMs: 8000,
      regions: const [
        AudioRegion(
          id: 'long',
          name: 'An Extremely Long Section Name',
          section: 'An Extremely Long Section Name',
          startMs: 0,
          endMs: 8000,
        ),
      ],
    );
    addTearDown(view.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            child: SongMapOverview(
              view: view,
              entry: PracticeRegionsScreenFixture.entry().copyWith(
                peaks: const [20],
              ),
              positionMs: 0,
              playing: false,
              selectedIndices: const {},
              candidateBoundariesMs: const {},
              noteTicks: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('An Extremely Long Section Name'), findsNothing);
  });

  testWidgets('unnamed sections use ordered Region letters on pads', (
    tester,
  ) async {
    final view = SongMapView(
      durationMs: 8000,
      regions: const [
        AudioRegion(id: 'first', name: '', startMs: 0, endMs: 4000),
        AudioRegion(id: 'second', name: '', startMs: 4000, endMs: 8000),
      ],
    );
    addTearDown(view.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SongMapPads(view: view)),
      ),
    );

    expect(find.text('Region A'), findsOneWidget);
    expect(find.text('Region B'), findsOneWidget);
    expect(find.text('Unnamed'), findsNothing);
  });
}
