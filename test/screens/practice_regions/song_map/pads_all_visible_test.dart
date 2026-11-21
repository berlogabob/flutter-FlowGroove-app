import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('all eight section pads can be scrolled into view', (
    tester,
  ) async {
    final regions = List.generate(
      8,
      (index) => AudioRegion(
        id: 'region-$index',
        name: 'Region ${index + 1}',
        section: 'Section ${index + 1}',
        startMs: index * 4000,
        endMs: (index + 1) * 4000,
      ),
    );
    final view = SongMapView(regions: regions, durationMs: 32000);
    addTearDown(view.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 300, child: SongMapPads(view: view)),
        ),
      ),
    );

    for (var index = 0; index < regions.length; index++) {
      final pad = find.byKey(ValueKey('song-map-pad-region-$index'));
      await tester.scrollUntilVisible(
        pad,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(pad, findsOneWidget);
    }
  });
}
