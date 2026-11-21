import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_minimap.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('tap at half width seeks to half the song duration', (tester) async {
    int? soughtMs;
    await tester.pumpWidget(
      MaterialApp(
        theme: MonoPulseTheme.theme,
        home: Center(
          child: SizedBox(
            width: 200,
            child: SongMapMinimap(
              durationMs: 10000,
              regions: const [
                AudioRegion(id: 'intro', name: 'Intro', startMs: 0, endMs: 2000),
                AudioRegion(id: 'chorus', name: 'Chorus 1', startMs: 2000, endMs: 10000),
              ],
              viewportStartMs: 2000,
              viewportEndMs: 5000,
              onSeek: (ms) => soughtMs = ms,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SongMapMinimap)).height, 40);
    await tester.tapAt(tester.getCenter(find.byType(SongMapMinimap)));
    expect(soughtMs, 5000);
  });
}
