import 'package:flowgroove/screens/practice_regions/song_map/song_map_tempo_banner.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows the measured tempo and offers Stretch and Keep', (
    tester,
  ) async {
    var stretches = 0;
    var keeps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: MonoPulseTheme.theme,
        home: Scaffold(
          body: SongMapTempoBanner(
            measuredBpm: 80.49,
            onStretch: () => stretches++,
            onKeep: () => keeps++,
          ),
        ),
      ),
    );

    expect(
      find.text('Audio runs at 80.49 BPM · Stretch to 80 / Keep'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Stretch to 80'));
    await tester.tap(find.widgetWithText(TextButton, 'Keep'));
    expect(stretches, 1);
    expect(keeps, 1);
  });

  test('stretch factor uses measured BPM and respects snapBpm', () {
    expect(songMapStretchTarget(80.49), 80);
    expect(songMapStretchFactor(80.49), closeTo(80 / 80.49, 1e-12));
    expect(songMapStretchTarget(80.6), 81);
    expect(songMapStretchFactor(80.6), closeTo(81 / 80.6, 1e-12));
    expect(songMapStretchTarget(80.03), isNull);
    expect(songMapStretchFactor(80.03), 1);
    expect(songMapStretchTarget(80), isNull);
    expect(songMapStretchFactor(null), 1);
  });
}
