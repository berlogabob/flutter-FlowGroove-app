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
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/utils/quantize.dart';
import 'package:flowgroove/widgets/chord_chart_view.dart';
import 'package:flowgroove/widgets/practice/instrument_strip.dart';
import 'package:flowgroove/widgets/practice/launchpad_view.dart';
import 'package:flowgroove/widgets/practice/section_card.dart';
import 'package:flowgroove/widgets/practice/section_pad.dart';
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
    await tester.ensureVisible(find.byType(InstrumentStrip));
    await tester.pump();
    await tester.drag(find.byType(InstrumentStrip), const Offset(0, -250));
    await tester.pump();
    expect(tester.getRect(row), before);
    expect(find.text('Play').hitTestable(), findsOneWidget);
    expect(find.text('Stop').hitTestable(), findsOneWidget);
    expect(find.text('Loop').hitTestable(), findsOneWidget);
    expect(find.text('Quantize: Bar').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Stop'));
    expect(transport.stops, [false]);
    expect(tester.takeException(), isNull);
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

  testWidgets('transport controls loop, quantize, play and stop at bar', (
    tester,
  ) async {
    final transport = _Transport(_state(2));
    await _pump(tester, transport);
    await tester.tap(find.text('Play'));
    await tester.tap(find.text('Loop'));
    await tester.pump();
    expect(transport.state.loop, isFalse);
    await tester.tap(find.text('Quantize: Bar'));
    await tester.pump();
    expect(transport.state.quantize, Quantize.beat);
    expect(find.text('Quantize: Beat'), findsOneWidget);
    await tester.longPress(find.text('Stop'));
    expect(transport.launches, ['s0']);
    expect(transport.stops, [true]);
  });

  testWidgets('instrument chips mute, solo and toggle minus one', (
    tester,
  ) async {
    final transport = _Transport(_state(2));
    await _pump(tester, transport);
    await tester.ensureVisible(find.text('Bass'));
    await tester.tap(find.text('Bass'));
    await tester.pump();
    await tester.tap(find.text('Bass'));
    await tester.pump();
    expect(transport.mutes, [('Bass', true), ('Bass', false)]);
    await tester.longPress(find.text('Bass'));
    await tester.pump();
    expect(transport.solos, [('Bass', true)]);
    expect(find.text('Bass · Solo'), findsOneWidget);
    await tester.tap(find.text('I play this').first);
    await tester.pump();
    expect(transport.minusOnes, ['Bass']);
    await tester.tap(find.text('I play this').first);
    await tester.pump();
    expect(transport.mutes.last, ('Bass', false));
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
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('metronome replaces backing chooser with pinned launchpad', (
    tester,
  ) async {
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
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          metronomeProvider.overrideWith(() => _Metronome(song: song)),
          backingTransportProvider.overrideWith(() => _Transport(_state(12))),
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
    expect(find.byType(LaunchpadView), findsOneWidget);
    expect(find.text('Backing tracks'), findsNothing);
    final row = find.byKey(const ValueKey('launchpad-transport'));
    final before = tester.getRect(row);
    await tester.ensureVisible(find.byType(InstrumentStrip));
    await tester.pump();
    expect(tester.getRect(row), before);
    expect(find.text('Stop').hitTestable(), findsOneWidget);
  });

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
