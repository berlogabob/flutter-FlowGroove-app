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
import 'package:flowgroove/widgets/metronome/drum_practice_panel.dart';
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

  final entries = <SongLabEntry>[];
  final saved = <SongLabEntry>[];
  String? savedBandId;

  @override
  Stream<List<SongLabEntry>> watchEntries(String songId, {String? bandId}) =>
      Stream.value(entries);

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    saved.add(entry);
    savedBandId = bandId;
  }
}

void main() {
  late MetronomeTestRuntime runtime;
  late ProviderContainer container;
  late _Repository repo;
  late _Player player;
  late bool canEdit;
  late bool canEditBand;

  setUp(() {
    runtime = MetronomeTestRuntime();
    repo = _Repository();
    player = _Player();
    canEdit = true;
    canEditBand = true;
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(auth.currentUser).thenReturn(user);
    when(user.uid).thenReturn('author');
    container = ProviderContainer(
      overrides: [
        ...runtime.overrides,
        firebaseAuthProvider.overrideWithValue(auth),
        firebaseFirestoreProvider.overrideWithValue(MockFirebaseFirestore()),
        drumPlayerProvider.overrideWithValue(player),
        labRepositoryProvider.overrideWithValue(repo),
        canEditProvider.overrideWith((ref) => canEdit),
        canEditBandProvider.overrideWith((ref, bandId) => canEditBand),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await runtime.dispose();
  });

  Future<void> openPanel(WidgetTester tester, {String? bandId}) async {
    tester.view.physicalSize = const Size(1100, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: const Text('Bottom bar'),
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: DrumPracticePanel(songId: 'song', bandId: bandId),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final bandId in <String?>[null, 'band']) {
    testWidgets('New pattern opens a full-screen editor in scope $bandId', (
      tester,
    ) async {
      await openPanel(tester, bandId: bandId);
      await tester.tap(find.text('New pattern'));
      await tester.pumpAndSettle();
      final editor = tester.widget<DrumGridEditor>(find.byType(DrumGridEditor));
      expect(editor.songId, 'song');
      expect(editor.bandId, bandId);
      expect(editor.entry, isNull);
      expect(find.text('Bottom bar'), findsNothing);
      final context = tester.element(find.byType(DrumGridEditor));
      expect(Navigator.of(context), Navigator.of(context, rootNavigator: true));
      expect(ModalRoute.of(context)!.fullscreenDialog, isTrue);
      await tester.tap(find.byKey(const ValueKey('drum-cell-kick-0')));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.songId, 'song');
      expect(repo.saved.single.bandId, bandId);
      expect(repo.savedBandId, bandId);
      expect(repo.saved.single.pattern!.hits.single.note, 36);
      expect(find.byType(DrumGridEditor), findsNothing);
      expect(find.text('Bottom bar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Edit pattern opens the listed entry', (tester) async {
    final entry = SongLabEntry(
      id: 'existing',
      songId: 'song',
      bandId: 'band',
      type: LabEntryType.midi,
      title: 'Existing beat',
      authorId: 'author',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      midi: MidiPattern(
        name: 'Existing beat',
        bars: 1,
        beatsPerBar: 4,
        stepsPerBeat: 4,
        hits: const [MidiHit(step: 0, note: 36, vel: 90)],
      ).toJson(),
    );
    repo.entries.add(entry);
    await openPanel(tester, bandId: 'band');
    await tester.tap(find.byTooltip('Edit pattern'));
    await tester.pumpAndSettle();
    final editor = tester.widget<DrumGridEditor>(find.byType(DrumGridEditor));
    expect(editor.entry, same(entry));
    expect(editor.songId, entry.songId);
    expect(editor.bandId, entry.bandId);
    await tester.enterText(find.byType(TextField), 'Edited beat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.id, entry.id);
    expect(repo.saved.single.title, 'Edited beat');
    expect(tester.takeException(), isNull);
  });

  for (final demo in [true, false]) {
    testWidgets(
      '${demo ? 'Demo users' : 'Band viewers'} can preview drafts but get a save explanation',
      (tester) async {
        canEdit = !demo;
        canEditBand = false;
        await openPanel(tester, bandId: demo ? null : 'band');
        expect(
          container.read(canEditBandProvider('band')),
          isFalse,
          reason: 'before opening',
        );
        await tester.tap(find.text('New pattern'));
        await tester.pumpAndSettle();
        expect(
          container.read(canEditBandProvider('band')),
          isFalse,
          reason: 'after opening',
        );
        await tester.tap(find.byKey(const ValueKey('drum-cell-kick-0')));
        await tester.tap(find.text('Play'));
        await tester.pumpAndSettle();
        expect(player.playing, isTrue);
        expect(player.pattern!.hits.single.note, 36);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
              .onPressed,
          isNotNull,
        );
        expect(container.read(canEditBandProvider('band')), isFalse);
        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repo.saved, isEmpty);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining(
            demo ? 'demo or read-only' : 'permission to edit this band',
          ),
          findsOneWidget,
        );
        expect(repo.saved, isEmpty);
        expect(find.byType(DrumGridEditor), findsOneWidget);
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();
        expect(player.playing, isFalse);
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
