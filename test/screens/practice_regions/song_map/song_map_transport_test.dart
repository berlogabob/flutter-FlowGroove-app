import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('controls call callbacks with updated values', (tester) async {
    var played = false;
    var stopped = false;
    var speedTapped = false;
    bool? loop;
    bool? countIn;
    bool? click;
    bool? clickAndDrums;

    await tester.pumpWidget(
      MaterialApp(
        theme: MonoPulseTheme.theme,
        home: Scaffold(
          bottomNavigationBar: SongMapTransport(
            playing: false,
            speedPercent: 75,
            loop: false,
            countIn: false,
            click: false,
            clickAndDrums: false,
            onPlay: () => played = true,
            onStop: () => stopped = true,
            onSpeedTap: () => speedTapped = true,
            onLoopChanged: (value) => loop = value,
            onCountInChanged: (value) => countIn = value,
            onClickChanged: (value) => click = value,
            onClickAndDrumsChanged: (value) => clickAndDrums = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play'));
    await tester.tap(find.text('75%'));
    await tester.tap(find.byKey(const ValueKey('loop')));
    await tester.tap(find.byKey(const ValueKey('count-in')));
    await tester.tap(find.byKey(const ValueKey('click')));
    await tester.tap(find.byKey(const ValueKey('click-and-drums')));

    expect(played, isTrue);
    expect(speedTapped, isTrue);
    expect(loop, isTrue);
    expect(countIn, isTrue);
    expect(click, isTrue);
    expect(clickAndDrums, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: MonoPulseTheme.theme,
        home: Scaffold(
          bottomNavigationBar: SongMapTransport(
            playing: true,
            speedPercent: 75,
            loop: false,
            countIn: false,
            click: false,
            clickAndDrums: false,
            onPlay: () {},
            onStop: () => stopped = true,
            onSpeedTap: () {},
            onLoopChanged: (_) {},
            onCountInChanged: (_) {},
            onClickChanged: (_) {},
            onClickAndDrumsChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pause'));
    expect(stopped, isTrue);
  });

  testWidgets('click and drums is disabled with a stretched audio tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MonoPulseTheme.theme,
        home: Scaffold(
          bottomNavigationBar: SongMapTransport(
            playing: false,
            speedPercent: 100,
            loop: false,
            countIn: false,
            click: false,
            clickAndDrums: false,
            stretched: true,
            onPlay: () {},
            onStop: () {},
            onSpeedTap: () {},
            onLoopChanged: (_) {},
            onCountInChanged: (_) {},
            onClickChanged: (_) {},
            onClickAndDrumsChanged: (_) {},
          ),
        ),
      ),
    );

    final chip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('click-and-drums')),
    );
    expect(chip.onSelected, isNull);
    expect(
      find.byTooltip('Click & drums is unavailable while audio is stretched'),
      findsOneWidget,
    );
  });
}
