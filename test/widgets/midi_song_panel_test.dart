import 'dart:async';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_practice_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/widgets/midi/midi_song_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.mocks.dart';

const _tracks = [
  MidiTrackMeta(
    index: 2,
    name: 'Electric bass',
    channel: 0,
    program: 33,
    detectedRole: MidiRole.bass,
    noteCount: 20,
    minPitch: 28,
    maxPitch: 48,
  ),
  MidiTrackMeta(
    index: 4,
    name: 'Piano',
    channel: 1,
    program: 0,
    detectedRole: MidiRole.keys,
    noteCount: 30,
    minPitch: 48,
    maxPitch: 84,
  ),
];

SongLabEntry _entry({String? bandId}) => SongLabEntry(
  id: 'midi',
  songId: 'song',
  bandId: bandId,
  type: LabEntryType.midi,
  title: 'Practice song',
  authorId: 'user',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  midiSong: const MidiSongMeta(ppq: 480, initialBpm: 120, tracks: _tracks),
);

class _Practice extends MidiSongPracticeNotifier {
  _Practice(
    super.entry, {
    this.initial = const MidiSongPracticeState(tracks: _tracks),
  });

  final MidiSongPracticeState initial;
  final muteCalls = <(int, bool)>[];
  int loads = 0;
  FutureOr<void> Function(SongLabEntry)? persist;

  @override
  MidiSongPracticeState build() => initial;

  @override
  Future<void> loadEntry({
    FutureOr<void> Function(SongLabEntry)? onPersist,
  }) async {
    loads++;
    persist = onPersist;
  }

  @override
  void setMute(int index, {required bool mute}) {
    muteCalls.add((index, mute));
    state = state.copyWith(
      tracks: [
        for (var i = 0; i < state.tracks.length; i++)
          if (i == index)
            state.tracks[i].copyWith(mute: mute)
          else
            state.tracks[i],
      ],
    );
    unawaited(save());
  }

  Future<void> save() async {
    try {
      await persist?.call(
        entry.copyWith(
          midiSong: entry.midiSong!.copyWith(tracks: state.tracks),
        ),
      );
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  @override
  void setVolume(int index, double volume) {
    state = state.copyWith(
      tracks: [
        for (var i = 0; i < state.tracks.length; i++)
          if (i == index)
            state.tracks[i].copyWith(volume: volume)
          else
            state.tracks[i],
      ],
    );
  }

  @override
  void toggleSolo(int index) => state = state.copyWith(soloed: {index});
}

class _Metronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial().copyWith(bpm: 120);

  @override
  void toggle() => state = state.copyWith(isPlaying: !state.isPlaying);
}

class _Repository extends FirestoreLabRepository {
  _Repository()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  final saved = <(SongLabEntry, String?)>[];
  bool fail = false;

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    if (fail) throw StateError('Save failed');
    saved.add((entry, bandId));
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Practice practice,
  _Repository repository, {
  String? bandId,
  bool canEdit = false,
  bool canEditBand = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        midiSongPracticeProvider(practice.entry).overrideWith(() => practice),
        metronomeProvider.overrideWith(_Metronome.new),
        labRepositoryProvider.overrideWithValue(repository),
        canEditProvider.overrideWithValue(canEdit),
        canEditBandProvider.overrideWith((ref, id) => canEditBand),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MidiSongPanel(entry: practice.entry, bandId: bandId),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders track names, roles and controls; loads only once', (
    tester,
  ) async {
    final practice = _Practice(_entry());
    await _pump(tester, practice, _Repository());

    expect(find.text('Practice song'), findsOneWidget);
    expect(find.text('120 BPM'), findsOneWidget);
    for (final label in ['Electric bass', 'bass', 'Piano', 'keys']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text('Solo'), findsNWidgets(2));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(practice.muteCalls, [(0, true)]);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(practice.loads, 1);
  });

  testWidgets('shows provider errors inline', (tester) async {
    await _pump(
      tester,
      _Practice(
        _entry(),
        initial: const MidiSongPracticeState(error: 'MIDI load failed'),
      ),
      _Repository(),
    );

    expect(find.text('MIDI load failed'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows loading inline and disables Play', (tester) async {
    await _pump(
      tester,
      _Practice(_entry(), initial: const MidiSongPracticeState(loading: true)),
      _Repository(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  for (final band in [false, true]) {
    for (final allowed in [false, true]) {
      testWidgets(
        '${band ? 'band' : 'personal'} edits persist only with permission ($allowed)',
        (tester) async {
          // Band identity on the entry must also protect callers omitting bandId.
          final practice = _Practice(_entry(bandId: band ? 'band' : null));
          final repository = _Repository();
          await _pump(
            tester,
            practice,
            repository,
            canEdit: !band && allowed,
            canEditBand: band && allowed,
          );
          await tester.tap(find.byType(Switch).first);
          await tester.pump();

          expect(practice.muteCalls, [(0, true)]);
          expect(repository.saved.length, allowed ? 1 : 0);
          if (allowed) {
            expect(
              repository.saved.single.$1.midiSong!.tracks.first.mute,
              isTrue,
            );
            expect(repository.saved.single.$2, band ? 'band' : null);
          }
        },
      );
    }
  }

  testWidgets('volume, solo and Play/Stop update their providers', (
    tester,
  ) async {
    final practice = _Practice(_entry());
    await _pump(tester, practice, _Repository());
    await tester.tap(find.byType(Slider).first);
    await tester.tap(find.text('Solo').first);
    await tester.pump();
    expect(practice.state.tracks.first.volume, lessThan(1));
    expect(practice.state.soloed, {0});

    await tester.ensureVisible(find.text('Play'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('save errors show inline', (tester) async {
    await _pump(
      tester,
      _Practice(_entry()),
      _Repository()..fail = true,
      canEdit: true,
    );
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(find.textContaining('Save failed'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
