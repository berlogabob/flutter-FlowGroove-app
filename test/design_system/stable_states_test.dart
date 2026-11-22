import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart';
import 'package:flowgroove/screens/practice_regions/song_map/song_map_view.dart';
import 'package:flowgroove/screens/setlists/create_setlist_screen.dart';
import 'package:flowgroove/theme/mono_pulse_theme.dart';
import 'package:flowgroove/widgets/app_filter_chip.dart';
import 'package:flowgroove/widgets/bottom_nav_or_action_bar.dart';
import 'package:flowgroove/widgets/custom_button.dart';
import 'package:flowgroove/widgets/quick_action_button.dart';
import 'package:flowgroove/widgets/setlist_song_row.dart';
import 'package:flowgroove/widgets/tool_button.dart';
import 'package:flowgroove/widgets/tools/tool_mode_switcher.dart';
import 'package:flowgroove/widgets/tuner/transport_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/layout_stability.dart';
import '../helpers/layout_test_tuner.dart';
import '../helpers/mocks.dart';
import '../screens/practice_regions_screen_test.dart'
    show PracticeRegionsScreenFixture;

const _component = ValueKey('component under test');
const _playhead = ValueKey('song-map-playhead');
void _tap() {}
void _toggle(bool _) {}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MonoPulseTheme.theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 400),
            child: KeyedSubtree(key: _component, child: child),
          ),
        ),
      ),
    ),
  );
  // Advance implicit animations without waiting for indeterminate spinners.
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _compareStates(WidgetTester tester, List<Widget> states) async {
  await _pump(tester, states.first);
  final size = tester.getSize(find.byKey(_component));
  for (final state in states.skip(1)) {
    await expectStableLayout(tester, () => _pump(tester, state));
    expect(tester.getSize(find.byKey(_component)), size);
  }
}

void main() {
  testWidgets('layout helper detects unkeyed text reflow', (tester) async {
    Widget frame(String label) =>
        SizedBox(width: 180, child: Align(child: Text(label)));
    await _pump(tester, frame('Play'));
    await expectLater(
      () => expectStableLayout(tester, () => _pump(tester, frame('Pause'))),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('layout helper detects a moved key and supports an exception', (
    tester,
  ) async {
    const movingKey = ValueKey('moving');
    const moving = SizedBox(key: movingKey, width: 4, height: 4);
    const first = SizedBox(
      width: 360,
      height: 40,
      child: Align(alignment: Alignment.topLeft, child: moving),
    );
    const second = SizedBox(
      width: 360,
      height: 40,
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [moving]),
    );
    await _pump(tester, first);
    await expectLater(
      () => expectStableLayout(tester, () => _pump(tester, second)),
      throwsA(isA<TestFailure>()),
    );
    await expectStableLayout(
      tester,
      () => _pump(tester, first),
      allowChanged: {movingKey},
    );
  });

  for (final variant in ButtonVariant.values) {
    for (final size in ButtonSize.values) {
      for (final icon in [null, Icons.add]) {
        testWidgets(
          'CustomButton ${variant.name} ${size.name} icon=${icon != null}',
          (tester) async {
            await _compareStates(tester, [
              for (final (enabled, loading) in [
                (true, false),
                (false, false),
                (true, true),
                (true, false),
              ])
                CustomButton(
                  label: 'Save song',
                  variant: variant,
                  size: size,
                  icon: icon,
                  onPressed: enabled ? _tap : null,
                  isLoading: loading,
                ),
            ]);
          },
        );
      }
    }
  }

  testWidgets('AppFilterChip selected and unselected', (tester) async {
    await _compareStates(tester, [
      for (final selected in [false, true])
        AppFilterChip(label: 'Songs', selected: selected, onSelected: _toggle),
    ]);
  });

  testWidgets('bottom nav selection and badge', (tester) async {
    await _compareStates(tester, [
      for (final (index, badge) in [(0, false), (1, false), (1, true)])
        AppBottomBar.tabs(
          tabs: const [
            (
              label: 'Songs',
              icon: Icons.music_note_outlined,
              selectedIcon: Icons.music_note,
            ),
            (
              label: 'Bands',
              icon: Icons.group_outlined,
              selectedIcon: Icons.group,
            ),
          ],
          selectedIndex: index,
          onTabTap: (_) {},
          onMenuTap: _tap,
          menuHasBadge: badge,
        ),
    ]);
  });

  testWidgets('ToolModeSwitcher moves selection across both segments', (
    tester,
  ) async {
    await _compareStates(tester, [
      for (final mode in TunerMode.values)
        ToolModeSwitcher<TunerMode>(
          activeMode: mode,
          options: const [
            ToolModeOption(
              mode: TunerMode.listen,
              label: 'Listen mode',
              icon: Icons.mic,
            ),
            ToolModeOption(
              mode: TunerMode.generate,
              label: 'Tone',
              icon: Icons.graphic_eq,
            ),
          ],
          onModeChanged: (_) {},
        ),
    ]);
  });

  for (final compact in [false, true]) {
    testWidgets('QuickActionButton pressed and released, compact=$compact', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        QuickActionButton(
          icon: Icons.add,
          label: 'Song',
          onTap: () => taps++,
          isCompact: compact,
        ),
      );
      late TestGesture press;
      await expectStableLayout(tester, () async {
        press = await tester.startGesture(tester.getCenter(find.text('Song')));
      });
      await expectStableLayout(tester, press.up);
      expect(taps, 1);
    });

    testWidgets('ToolButton enabled and disabled, compact=$compact', (
      tester,
    ) async {
      await _compareStates(tester, [
        for (final enabled in [true, false, true])
          ToolButton(
            icon: Icons.tune,
            label: 'Tuner',
            onTap: enabled ? _tap : null,
            isCompact: compact,
          ),
      ]);
    });
  }

  for (final mode in TunerMode.values) {
    testWidgets('tuner transport active and inactive in ${mode.name} mode', (
      tester,
    ) async {
      final tuner = StabilityTuner(mode);
      await _pump(
        tester,
        ProviderScope(
          overrides: [tunerProvider.overrideWith(() => tuner)],
          child: const TransportBar(),
        ),
      );
      for (final active in [true, false]) {
        final icon = active
            ? (mode == TunerMode.generate ? Icons.play_arrow : Icons.mic)
            : Icons.stop;
        final action = find.descendant(
          of: find.byType(AnimatedContainer),
          matching: find.byIcon(icon),
        );
        await expectStableLayout(tester, () async {
          await tester.tap(action);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
        });
        expect(tuner.active, active);
      }
    });
  }

  testWidgets('SetlistSongRow keeps its key, BPM and Spotify columns', (
    tester,
  ) async {
    final songs = [
      for (final (i, (key, bpm, hasSpotify)) in [
        ('Bbm', 108, true),
        ('Eb', 92, false),
        (null, null, false),
        ('C', 8, true),
      ].indexed)
        MockDataHelper.createMockSong(
          id: 'song-$i',
          title: 'Song $i',
          ourKey: key,
          ourBPM: bpm,
          spotifyUrl: hasSpotify
              ? 'https://open.spotify.com/track/example'
              : null,
        ),
    ];
    final setlist = MockDataHelper.createMockSetlist(
      bandId: '',
      name: 'Gig Setlist',
      songIds: [for (final song in songs) song.id],
    );
    tester.view.physicalSize = const Size(420, 934);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(const AsyncData(null)),
          songsProvider.overrideWith((ref) => Stream.value(songs)),
          setlistsProvider.overrideWith((ref) => Stream.value([setlist])),
        ],
        child: MaterialApp(
          theme: MonoPulseTheme.theme,
          home: CreateSetlistScreen(setlist: setlist),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rowRects = <Size>[];
    final keyRects = <Rect>[];
    final bpmRects = <Rect>[];
    final spotifyRects = <Rect>[];
    final titleRects = <Rect>[];
    final actionRects = <Rect>[];
    for (final song in songs) {
      final title = find.text(song.title);
      final row = find.ancestor(
        of: title,
        matching: find.byType(SetlistSongRow),
      );
      final rowBox = tester.renderObject<RenderBox>(row);
      Rect local(Finder child) {
        final box = tester.renderObject<RenderBox>(
          find.descendant(of: row, matching: child),
        );
        return MatrixUtils.transformRect(
          box.getTransformTo(rowBox),
          Offset.zero & box.size,
        );
      }

      rowRects.add(rowBox.size);
      titleRects.add(local(title));
      keyRects.add(local(find.text(song.ourKey ?? '-')));
      actionRects.add(local(find.byIcon(Icons.person_outline)));
      if (song.ourBPM != null) {
        bpmRects.add(local(find.text('${song.ourBPM}')));
      }
      final spotify = find.byIcon(Icons.play_circle_fill);
      if (song.spotifyUrl != null) {
        spotifyRects.add(local(spotify));
      } else {
        expect(find.descendant(of: row, matching: spotify), findsNothing);
      }
    }
    for (final (label, rects) in [
      ('row sizes', rowRects),
      ('titles', titleRects),
      ('keys', keyRects),
      ('BPM', bpmRects),
      ('performer actions', actionRects),
      ('Spotify actions', spotifyRects),
    ]) {
      expect(rects.toSet(), hasLength(1), reason: label);
    }
  });

  testWidgets(
    'Song Map transport playback, toggles, speed and disabled drums',
    (tester) async {
      await _compareStates(tester, [
        for (final (playing, loop, countIn, click, drums, stretched, speed) in [
          (false, false, false, false, false, false, 75),
          (true, false, false, false, false, false, 75),
          (true, true, true, true, true, false, 100),
          (false, true, true, true, false, true, 100),
        ])
          SongMapTransport(
            playing: playing,
            speedPercent: speed,
            loop: loop,
            countIn: countIn,
            click: click,
            clickAndDrums: drums,
            stretched: stretched,
            onPlay: _tap,
            onStop: _tap,
            onSpeedTap: _tap,
            onLoopChanged: _toggle,
            onCountInChanged: _toggle,
            onClickChanged: _toggle,
            onClickAndDrumsChanged: _toggle,
          ),
      ]);
    },
  );

  testWidgets('Song Map pads idle, selected, playing, queued and disabled', (
    tester,
  ) async {
    final view = SongMapView(
      regions: const [
        AudioRegion(id: 'a', name: 'Intro', startMs: 0, endMs: 4000),
        AudioRegion(id: 'b', name: 'Verse', startMs: 4000, endMs: 8000),
      ],
      grid: const AudioGrid(bpm: 120),
      durationMs: 8000,
    );
    addTearDown(view.dispose);
    await _compareStates(tester, [
      for (final (selected, playing, queued, disabled, progress) in [
        (const <int>{}, null, null, const <int>{}, 0.0),
        ({0}, null, null, const <int>{}, 0.0),
        ({0}, 0, null, const <int>{}, 0.1),
        ({1}, 0, 1, const <int>{}, 0.9),
        (const <int>{}, null, null, {1}, 0.0),
      ])
        SongMapPads(
          view: view,
          selectedIndices: selected,
          playingIndex: playing,
          queuedIndex: queued,
          disabledIndices: disabled,
          progress: progress,
          onSelect: (_) {},
        ),
    ]);
  });

  final practice = PracticeRegionsScreenFixture();
  testWidgets('notes panel rows keep their geometry as playback advances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 934);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await practice.pump(
      tester,
      PracticeRegionsScreenFixture.entry().copyWith(
        peaks: const [20, 40, 20],
        notes: const [(ms: 0, text: 'Intro'), (ms: 1000, text: 'Cue')],
      ),
      theme: MonoPulseTheme.theme,
    );
    final cue = find.text('Cue');
    expect(cue, findsOneWidget);
    final color = tester.widget<Text>(cue).style!.color;
    final row = find.ancestor(of: cue, matching: find.byType(ListTile));
    final size = tester.getSize(row);
    await expectStableLayout(tester, () async {
      practice.emitPosition(1500);
      await practice.settleAudio(tester);
    }, allowChanged: {_playhead});
    expect(tester.widget<Text>(cue).style!.color, MonoPulseColors.accentOrange);
    expect(color, isNot(MonoPulseColors.accentOrange));
    expect(tester.getSize(row), size);
  });
}
