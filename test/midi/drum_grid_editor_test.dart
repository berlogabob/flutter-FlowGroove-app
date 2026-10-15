import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/drum_practice_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/songs/components/drum_grid_editor.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.mocks.dart';

class _Player implements DrumPlayer {
  MidiPattern? pattern;
  @override
  bool playing = false;
  @override
  Stream<int> get stepStream => const Stream.empty();
  @override
  Future<void> load(MidiPattern p, double bpm) async => pattern = p;
  @override
  Future<void> start() async => playing = true;
  @override
  Future<void> stop() async => playing = false;
  @override
  void setLaneGain(DrumLane lane, double gain) {}
  @override
  Future<void> dispose() async {}
}

class _Repository extends FirestoreLabRepository {
  _Repository()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  final saved = <SongLabEntry>[];
  String? bandId;
  bool fail = false;

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    if (fail) throw StateError('offline');
    saved.add(entry);
    this.bandId = bandId;
  }
}

void main() {
  late ProviderContainer container;
  late MetronomeTestRuntime runtime;
  late _Player player;
  late _Repository repo;
  late bool canEdit;
  late ValueNotifier<bool> dirty;

  setUp(() {
    runtime = MetronomeTestRuntime();
    player = _Player();
    repo = _Repository();
    canEdit = true;
    dirty = ValueNotifier(false);
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(auth.currentUser).thenReturn(user);
    when(user.uid).thenReturn('author');
    container = ProviderContainer(
      overrides: [
        ...runtime.overrides,
        drumPlayerProvider.overrideWithValue(player),
        labRepositoryProvider.overrideWithValue(repo),
        firebaseAuthProvider.overrideWithValue(auth),
        canEditBandProvider('band').overrideWith((ref) => canEdit),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await runtime.dispose();
  });

  Future<void> open(
    WidgetTester tester, {
    SongLabEntry? entry,
    String? bandId,
    ValueNotifier<bool>? dirtyNotifier,
  }) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showModalBottomSheet<SongLabEntry>(
                    context: context,
                    isScrollControlled: true,
                    constraints: const BoxConstraints(maxWidth: 1100),
                    builder: (_) => DrumGridEditor(
                      songId: 'song',
                      bandId: bandId,
                      entry: entry,
                      dirty: dirtyNotifier ?? dirty,
                    ),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder cell(DrumLane lane, int step) =>
      find.byKey(ValueKey('drum-cell-${lane.name}-$step'));

  Future<MidiPattern> preview(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Play'));
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(player.playing, isTrue);
    final pattern = player.pattern!;
    expect(container.read(drumPracticeProvider).pattern, same(pattern));
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    return pattern;
  }

  testWidgets(
    'cells build a named 16-step MIDI pattern across all nine lanes',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '  Groove  ');
      const notes = [36, 38, 42, 46, 50, 47, 43, 49, 51];
      for (var i = 0; i < DrumLane.values.length; i++) {
        await tester.tap(cell(DrumLane.values[i], i));
        await tester.pump();
      }
      final pattern = await preview(tester);
      expect(pattern.name, 'Groove');
      expect(pattern.bars, 1);
      expect(pattern.beatsPerBar, 4);
      expect(pattern.stepsPerBeat, 4);
      expect(pattern.totalSteps, 16);
      expect(pattern.hits.map((h) => (h.step, h.note, h.vel)), [
        for (var i = 0; i < notes.length; i++) (i, notes[i], 90),
      ]);
      expect(repo.saved, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a cell cycles normal, accent, ghost, off without duplicate hits',
    (tester) async {
      await open(tester);
      for (final velocity in [90, 120, 40, 0]) {
        await tester.tap(cell(DrumLane.kick, 0));
        await tester.pump();
        final pattern = await preview(tester);
        if (velocity == 0) {
          expect(pattern.hits, isEmpty);
        } else {
          expect(pattern.hits, hasLength(1));
          expect(pattern.hits.single.toJson(), {
            'step': 0,
            'note': 36,
            'vel': velocity,
          });
        }
      }
    },
  );

  testWidgets(
    'bars resize from 16 to 64 cells per lane and discard trimmed hits',
    (tester) async {
      await open(tester);
      await tester.tap(cell(DrumLane.kick, 0));
      await tester.tap(find.text('4 bars'));
      await tester.pumpAndSettle();
      expect(cell(DrumLane.ride, 63), findsOneWidget);
      await tester.ensureVisible(cell(DrumLane.kick, 63));
      await tester.tap(cell(DrumLane.kick, 63));
      await tester.pump();
      final expanded = await preview(tester);
      expect(expanded.totalSteps, 64);
      expect(expanded.hits.map((h) => h.step), [0, 63]);
      for (final bars in [3, 2, 1, 4]) {
        await tester.tap(find.text('$bars ${bars == 1 ? 'bar' : 'bars'}'));
        await tester.pumpAndSettle();
        expect(dirty.value, isTrue);
        expect(cell(DrumLane.ride, bars * 16 - 1), findsOneWidget);
        expect(cell(DrumLane.ride, bars * 16), findsNothing);
        final resized = await preview(tester);
        expect(resized.bars, bars);
        expect(resized.totalSteps, bars * 16);
        expect(resized.hits.map((h) => h.step), [0]);
      }
    },
  );

  for (final bandId in <String?>[null, 'band']) {
    testWidgets('saves a new MIDI entry with scope $bandId', (tester) async {
      await open(tester, bandId: bandId);
      await tester.enterText(find.byType(TextField), 'Beat');
      await tester.tap(cell(DrumLane.snare, 4));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final entry = repo.saved.single;
      expect(entry.id, isNotEmpty);
      expect(entry.songId, 'song');
      expect(entry.bandId, bandId);
      expect(repo.bandId, bandId);
      expect(entry.type, LabEntryType.midi);
      expect(entry.authorId, 'author');
      expect(entry.title, 'Beat');
      expect(entry.pattern!.hits.single.toJson(), {
        'step': 4,
        'note': 38,
        'vel': 90,
      });
      expect(find.byType(DrumGridEditor), findsNothing);
    });
  }

  testWidgets(
    'edits an existing entry while retaining its identity and metadata',
    (tester) async {
      final entry = SongLabEntry(
        id: 'existing',
        songId: 'song',
        bandId: 'band',
        type: LabEntryType.midi,
        authorId: 'original',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        title: 'Original',
        body: 'Keep me',
        tags: const ['practice'],
        midi: MidiPattern(
          name: 'Original',
          bars: 2,
          beatsPerBar: 4,
          stepsPerBeat: 4,
          hits: const [MidiHit(step: 0, note: 35, vel: 90)],
        ).toJson(),
      );
      await open(tester, entry: entry, bandId: 'band');
      expect(find.text('Original'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Edited');
      await tester.tap(cell(DrumLane.kick, 0));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(dirty.value, isTrue);
      final saved = repo.saved.single;
      expect(saved.id, entry.id);
      expect(saved.createdAt, entry.createdAt);
      expect(saved.updatedAt.isAfter(entry.updatedAt), isTrue);
      expect(saved.authorId, 'original');
      expect(saved.body, 'Keep me');
      expect(saved.tags, ['practice']);
      expect(saved.pattern!.name, 'Edited');
      expect(saved.pattern!.bars, 2);
      expect(saved.pattern!.hits.single.vel, 120);
      expect(entry.pattern!.hits.single.vel, 90);
    },
  );

  testWidgets('blank names and revoked band permission prevent saving', (
    tester,
  ) async {
    await open(tester, bandId: 'band');
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.pump();
    final save = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
        .onPressed!;
    canEdit = false;
    container.invalidate(canEditBandProvider('band'));
    await tester.pumpAndSettle();
    save();
    await tester.pumpAndSettle();
    expect(repo.saved, isEmpty);
    expect(find.byType(DrumGridEditor), findsOneWidget);
  });

  testWidgets('band viewers cannot change or save the grid', (tester) async {
    canEdit = false;
    await open(tester, bandId: 'band');
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.widget<InkWell>(cell(DrumLane.kick, 0)).onTap, isNull);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2 bars'))
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    expect(repo.saved, isEmpty);
  });

  testWidgets(
    'save errors keep the draft available for retry; closing stops preview',
    (tester) async {
      await open(tester);
      repo.fail = true;
      await tester.tap(cell(DrumLane.kick, 0));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Failed to save drum pattern'),
        findsOneWidget,
      );
      expect(find.byType(DrumGridEditor), findsOneWidget);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(player.playing, isTrue);
      repo.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.pattern!.hits.single.vel, 90);
      expect(player.playing, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
