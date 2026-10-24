import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/section_span.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/utils/play_mode.dart';
import 'package:flowgroove/utils/quantize.dart';
import 'package:flowgroove/widgets/chord_chart_view.dart';
import 'package:flowgroove/widgets/practice/launchpad_view.dart';
import 'package:flowgroove/widgets/practice/note_editor_sheet.dart';
import 'package:flowgroove/widgets/practice/section_card.dart';
import 'package:flowgroove/widgets/practice/section_pad.dart';
import 'package:flowgroove/widgets/practice/track_console.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/mocks.mocks.dart';

class _Metronome extends MetronomeNotifier {
  _Metronome({this.song});

  final Song? song;
  @override
  MetronomeState build() =>
      MetronomeState.initial().copyWith(bpm: 124, loadedSong: song);
}

class _Transport extends BackingTransportNotifier {
  _Transport(this.initial);

  final BackingTransportState initial;
  final launches = <String>[];
  final stops = <bool>[];
  final mutes = <(String, bool)>[];
  final solos = <(String, bool)>[];
  final minusOnes = <String>[];
  final volumes = <(String, double)>[];
  List<Section>? attached;

  @override
  BackingTransportState build() => initial;

  @override
  Future<void> attach(SongLabEntry entry, List<Section> sections) async {
    attached = sections;
  }

  @override
  Future<void> launch(String sectionId) async => launches.add(sectionId);

  @override
  Future<void> stop({bool atBar = false}) async => stops.add(atBar);

  @override
  void muteStem(String role, {bool mute = true}) => mutes.add((role, mute));

  @override
  void soloStem(String role, {bool solo = true}) => solos.add((role, solo));

  @override
  void minusOne(String role) => minusOnes.add(role);

  @override
  void setStemVolume(String name, double volume) => volumes.add((name, volume));

  BackingTransportState get snapshot => state;
  set snapshot(BackingTransportState next) => state = next;
}

final _entry = SongLabEntry(
  id: 'midi',
  songId: 'song',
  type: LabEntryType.midi,
  authorId: 'user',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  midiSong: const MidiSongMeta(
    fileUrl: 'test.mid',
    ppq: 480,
    initialBpm: 124,
    tracks: [],
  ),
);

const _midi = MidiSongData(
  ppq: 480,
  tempos: [],
  timeSigs: [],
  tracks: [
    MidiTrackData(
      index: 0,
      name: 'Bass',
      channel: 0,
      program: 33,
      notes: [MidiNote(tick: 0, dur: 30720, pitch: 40, vel: 100)],
    ),
    MidiTrackData(
      index: 1,
      name: 'Drums',
      channel: 9,
      program: 0,
      notes: [MidiNote(tick: 0, dur: 480, pitch: 36, vel: 100)],
    ),
  ],
);

List<Section> _sections(int count) => List.generate(
  count,
  (i) => Section(
    id: 's$i',
    name: 'Section ${i + 1}',
    duration: 4,
    chordChart: '[Am]Line $i',
  ),
);

BackingTransportState _state(int count, {String? playing, String? queued}) =>
    BackingTransportState(
      spans: List.generate(
        count,
        (i) => SectionSpan(sectionId: 's$i', startBar: i * 4, bars: 4),
      ),
      playingId: playing,
      queuedId: queued,
    );

Future<void> _pump(
  WidgetTester tester,
  _Transport transport, {
  int count = 2,
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        metronomeProvider.overrideWith(_Metronome.new),
        backingTransportProvider.overrideWith(() => transport),
        midiSongProvider(_entry).overrideWith((ref) async => _midi),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: LaunchpadView(entry: _entry, sections: _sections(count)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('tap pad calls launch with its section id', (tester) async {
    final transport = _Transport(_state(2));
    await _pump(tester, transport);
    await tester.tap(find.text('Section 2'));
    expect(transport.launches, ['s1']);
  });

  testWidgets('queued pad says Next bar and card previews queued chords', (
    tester,
  ) async {
    final transport = _Transport(_state(2, playing: 's0', queued: 's1'));
    await _pump(tester, transport);
    expect(find.text('Next bar'), findsOneWidget);
    expect(
      tester.widget<SectionCard>(find.byType(SectionCard)).section.id,
      's1',
    );
    expect(
      tester.widget<ChordChartView>(find.byType(ChordChartView)).chart,
      '[Am]Line 1',
    );
    transport.snapshot = _state(2, playing: 's0');
    await tester.pump();
    expect(
      tester.widget<SectionCard>(find.byType(SectionCard)).section.id,
      's0',
    );
  });

  testWidgets('12 sections wrap at 360 dp and double text scale', (
    tester,
  ) async {
    await _pump(tester, _Transport(_state(12)), count: 12, scale: 2);
    expect(find.byType(SectionPad), findsNWidgets(12));
    final pads = find.byType(SectionPad);
    final first = tester.getRect(pads.at(0));
    final second = tester.getRect(pads.at(1));
    final third = tester.getRect(pads.at(2));
    expect(first.top, second.top);
    expect(third.top, greaterThan(first.bottom));
    for (var i = 0; i < 12; i++) {
      final rect = tester.getRect(pads.at(i));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
    }
    await tester.drag(
      find.byKey(const ValueKey('launchpad-content')),
      const Offset(0, -3000),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('transport stays visible after scrolling instruments', (
    tester,
  ) async {
    final transport = _Transport(_state(12));
    await _pump(tester, transport, count: 12, scale: 2);
    final row = find.byKey(const ValueKey('launchpad-transport'));
    final before = tester.getRect(row);
    await tester.ensureVisible(find.byType(TrackConsole));
    await tester.pump();
    await tester.drag(find.byType(TrackConsole), const Offset(0, -250));
    await tester.pump();
    expect(tester.getRect(row), before);
    expect(find.text('Play').hitTestable(), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
    expect(find.text('Mode').hitTestable(), findsOneWidget);
    expect(find.text('Loop').hitTestable(), findsOneWidget);
    expect(find.text('Quantize').hitTestable(), findsOneWidget);
    expect(find.text('Bar').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MIDI menu offers edit, hide and (when allowed) add', (
    tester,
  ) async {
    final transport = _Transport(const BackingTransportState());
    await _pump(tester, transport);
    await tester.tap(find.byKey(const ValueKey('midi-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Edit arrangement'), findsOneWidget);
    expect(find.text('Hide MIDI'), findsOneWidget);
  });

  testWidgets('no spans shows one Song pad and attaches whole MIDI song', (
    tester,
  ) async {
    final transport = _Transport(const BackingTransportState());
    await _pump(tester, transport, count: 0);
    expect(find.byType(SectionPad), findsOneWidget);
    expect(find.text('Song'), findsOneWidget);
    expect(transport.attached!.single.duration, 16);
    await tester.tap(find.text('Song'));
    expect(transport.launches, ['song']);
  });

  testWidgets('transport buttons cycle play mode and quantize', (tester) async {
    final transport = _Transport(_state(2));
    await _pump(tester, transport);
    await tester.tap(find.text('Play'));
    expect(transport.launches, ['s0']);

    expect(transport.state.mode, PlayMode.loop);
    await tester.tap(find.text('Loop'));
    await tester.pump();
    expect(transport.state.mode, PlayMode.song);
    expect(find.text('Song'), findsOneWidget);
    await tester.tap(find.text('Song'));
    await tester.pump();
    expect(transport.state.mode, PlayMode.once);
    expect(find.text('Once'), findsOneWidget);
    await tester.tap(find.text('Once'));
    await tester.pump();
    expect(transport.state.mode, PlayMode.loop);

    expect(transport.state.quantize, Quantize.bar);
    await tester.tap(find.text('Bar'));
    await tester.pump();
    expect(transport.state.quantize, Quantize.block);
    expect(find.text('Block'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pump();
    expect(transport.state.quantize, Quantize.bar);
    expect(find.text('Beat'), findsNothing);
  });

  testWidgets('one Play/Stop button: Stop while playing, same column as Play', (
    tester,
  ) async {
    final idle = _Transport(_state(2));
    await _pump(tester, idle);
    final playRect = tester.getRect(find.text('Play'));
    final loopRect = tester.getRect(find.text('Loop'));

    await tester.pumpWidget(const SizedBox());
    final playing = _Transport(_state(2, playing: 's0'));
    await _pump(tester, playing);
    expect(find.text('Play'), findsNothing);
    expect(tester.getRect(find.text('Stop')).center.dx, playRect.center.dx);
    expect(tester.getRect(find.text('Loop')).center.dx, loopRect.center.dx);
    await tester.tap(find.text('Stop'));
    expect(playing.stops, [false]);
    await tester.longPress(find.text('Stop'));
    expect(playing.stops, [false, true]);
  });

  testWidgets('track strips mute and solo per track', (tester) async {
    final transport = _Transport(_state(2));
    await _pump(tester, transport);
    await tester.ensureVisible(find.byTooltip('Mute Bass'));
    await tester.tap(find.byTooltip('Mute Bass'));
    await tester.pump();
    await tester.tap(find.byTooltip('Mute Bass'));
    await tester.pump();
    expect(transport.mutes, [('Bass', true), ('Bass', false)]);
    await tester.tap(find.byTooltip('Solo Bass'));
    await tester.pump();
    expect(transport.solos, [('Bass', true)]);
    expect(find.byTooltip('Mute Drums'), findsOneWidget);
    expect(find.text('Drum kit'), findsOneWidget);
  });

  testWidgets('Bass strip opens the note editor', (tester) async {
    final transport = _Transport(_state(2));
    await _pump(tester, transport);
    final edit = find.byTooltip('Edit notes of Bass');
    expect(edit, findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pump();
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditorSheet), findsOneWidget);
  });

  testWidgets('honest MIDI length, coverage and rendering warning', (
    tester,
  ) async {
    final transport = _Transport(_state(12).copyWith(rendering: true));
    await _pump(tester, transport, count: 12);
    expect(find.text('MIDI 124 BPM · 16 bars'), findsOneWidget);
    expect(find.text('Covers 16 of 48 bars'), findsOneWidget);
    expect(find.text('Rendering 124 BPM…'), findsOneWidget);
    await tester.tap(find.text('Section 1'), warnIfMissed: false);
    expect(transport.launches, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Play'))
          .onPressed,
      isNull,
    );
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'metronome keeps backing chooser with pinned launchpad at $size',
      (tester) async {
        final sections = _sections(12);
        final song = Song(
          id: 'song',
          title: 'Practice song',
          artist: 'Artist',
          sections: sections,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final auth = MockFirebaseAuth();
        final user = MockUser();
        when(auth.currentUser).thenReturn(user);
        when(user.uid).thenReturn('user');
        final transport = _Transport(_state(12));
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firebaseAuthProvider.overrideWithValue(auth),
              authStateProvider.overrideWith((ref) => Stream.value(user)),
              canEditProvider.overrideWithValue(false),
              metronomeProvider.overrideWith(() => _Metronome(song: song)),
              backingTransportProvider.overrideWith(() => transport),
              labEntriesProvider((
                'song',
                null,
              )).overrideWith((ref) => Stream.value([_entry])),
              midiSongProvider(_entry).overrideWith((ref) async => _midi),
            ],
            child: const MaterialApp(home: MetronomeScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(find.byType(LaunchpadView), findsOneWidget);
        final chooser = find.widgetWithText(OutlinedButton, 'Backing tracks');
        expect(chooser, findsOneWidget);
        await tester.ensureVisible(chooser);
        await tester.pumpAndSettle();
        await tester.tap(chooser);
        await tester.pumpAndSettle();
        expect(find.text('Drum pattern'), findsOneWidget);
        expect(find.text('MIDI song'), findsOneWidget);
        expect(find.text('Add MIDI file'), findsNothing);
        expect(transport.launches, isEmpty);
        Navigator.of(tester.element(find.text('Drum pattern'))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(LaunchpadView), findsOneWidget);
        final row = find.byKey(const ValueKey('launchpad-transport'));
        final before = tester.getRect(row);
        await tester.ensureVisible(find.byType(TrackConsole));
        await tester.pump();
        expect(tester.getRect(row), before);
        expect(find.text('Play').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('iOS hides launchpad without attaching backing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final transport = _Transport(_state(2));
    await _pump(tester, transport);
    expect(find.byType(SectionPad), findsNothing);
    expect(transport.attached, isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
