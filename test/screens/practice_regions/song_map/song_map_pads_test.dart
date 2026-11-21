import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_view.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const regions = [
    AudioRegion(id: 'a', name: 'Verse', startMs: 0, endMs: 4000, section: 'Verse'),
    AudioRegion(id: 'b', name: 'Chorus', startMs: 4000, endMs: 8000, section: 'Chorus'),
  ];

  testWidgets('playing pad uses accentOrange fill', (tester) async {
    final view = SongMapView(regions: regions, durationMs: 8000);
    addTearDown(view.dispose);
    await tester.pumpWidget(MaterialApp(theme: MonoPulseTheme.theme, home: Scaffold(body: SongMapPads(view: view, playingIndex: 0))));
    final material = tester.widget<Material>(find.ancestor(of: find.byKey(const ValueKey('song-map-pad-a')), matching: find.byType(Material)).first);
    expect(material.color, MonoPulseColors.accentOrange);
  });

  testWidgets('range emits inclusive start and end indices', (tester) async {
    final view = SongMapView(regions: regions, durationMs: 8000);
    addTearDown(view.dispose);
    (int, int)? range;
    await tester.pumpWidget(MaterialApp(theme: MonoPulseTheme.theme, home: Scaffold(body: SongMapPads(view: view, onRange: (value) => range = value))));
    await tester.tap(find.text('Range'));
    await tester.tap(find.byKey(const ValueKey('song-map-pad-a')));
    await tester.tap(find.byKey(const ValueKey('song-map-pad-b')));
    expect(range, (0, 1));
  });
}
