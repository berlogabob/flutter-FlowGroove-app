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

    final tempo = find.text('80.49 BPM');
    final stretch = find.widgetWithText(OutlinedButton, 'Stretch to 80');
    final keep = find.widgetWithText(TextButton, 'Keep');
    expect(tempo, findsOneWidget);
    expect(tester.getCenter(stretch).dy, tester.getCenter(tempo).dy);
    expect(tester.getCenter(keep).dy, tester.getCenter(tempo).dy);
    expect(tester.getSize(stretch).shortestSide, greaterThanOrEqualTo(48));
    expect(tester.getSize(keep).shortestSide, greaterThanOrEqualTo(48));
    await tester.tap(stretch);
    await tester.tap(keep);
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
