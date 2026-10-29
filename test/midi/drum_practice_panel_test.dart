import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/drum_practice_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_player.dart';
import 'package:flowgroove/widgets/metronome/drum_practice_panel.dart';
import 'package:flowgroove/widgets/midi/drum_kit_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/metronome_test_runtime.dart';
import '../helpers/mocks.mocks.dart';
import 'package:flowgroove/utils/snackbar.dart' show rootScaffoldMessengerKey;

class _Player implements DrumPlayer {
  @override
  bool playing = false;
  double? loadedBpm;
  @override
  Stream<int> get stepStream => const Stream.empty();
  @override
  Future<void> load(MidiPattern p, double bpm) async => loadedBpm = bpm;
  @override
  Future<void> start() async => playing = true;
  @override
  Future<void> stop() async => playing = false;
  @override
  void setLaneGain(DrumLane lane, double gain) {}
  @override
  Future<void> dispose() async {}
}

class _LabRepo extends FirestoreLabRepository {
  _LabRepo()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  final entries = <SongLabEntry>[];
  final saved = <SongLabEntry>[];
  final watches = <(String, String?)>[];
  String? savedBandId;

  @override
  Stream<List<SongLabEntry>> watchEntries(String songId, {String? bandId}) {
    watches.add((songId, bandId));
    return Stream.value(entries);
  }

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    saved.add(entry);
    savedBandId = bandId;
  }
}

void main() {
  final song = Song(
    id: 'song-1',
    title: 'Song',
    artist: 'Artist',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final pattern = MidiPattern(
    name: 'Beat',
    bars: 1,
    beatsPerBar: 4,
    stepsPerBeat: 4,
    hits: const [MidiHit(step: 0, note: 36, vel: 100)],
  );
  late ProviderContainer container;
  late MetronomeTestRuntime runtime;
  late _LabRepo repo;
  late _Player player;
  late int repoBuilds;
  late int playerBuilds;
  late bool canEditBand;

  setUp(() {
    runtime = MetronomeTestRuntime();
    repo = _LabRepo();
    player = _Player();
    repoBuilds = 0;
    playerBuilds = 0;
    canEditBand = false;
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(auth.currentUser).thenReturn(user);
    when(user.uid).thenReturn('user-1');
    container = ProviderContainer(
      overrides: [
        ...runtime.overrides,
        firebaseAuthProvider.overrideWithValue(auth),
        canEditBandProvider('band-1').overrideWith((ref) => canEditBand),
        labRepositoryProvider.overrideWith((ref) {
          repoBuilds++;
          return repo;
        }),
        drumPlayerProvider.overrideWith((ref) {
          playerBuilds++;
          return player;
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await runtime.dispose();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hidden without a song; providers stay lazy until Drums is tapped',
    (tester) async {
      await pump(tester, const MetronomeScreen());
      // The Drums button is always present; it is disabled (no song) and the
      // panel providers stay lazy until the button is actually tapped.
      expect(find.byTooltip('Backing tracks'), findsOneWidget);
      expect(find.byType(DrumPracticePanel), findsNothing);
      expect(repoBuilds, 0);
      expect(playerBuilds, 0);

      container.read(metronomeProvider.notifier).loadSongTempo(song);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Backing tracks'), findsOneWidget);
      expect(find.byType(DrumPracticePanel), findsNothing);
      expect(repoBuilds, 0);
      expect(playerBuilds, 0);

      await tester.tap(find.byTooltip('Backing tracks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drum pattern'));
      await tester.pumpAndSettle();
      expect(find.byType(DrumPracticePanel), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text('No MIDI patterns yet'), findsOneWidget);
      expect(repoBuilds, 1);
      expect(playerBuilds, 1);
      expect(repo.watches, [('song-1', null)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lists only MIDI entries, selects a kit and toggles playback and speed',
    (tester) async {
      for (final type in [LabEntryType.note, LabEntryType.midi]) {
        repo.entries.add(
          SongLabEntry(
            id: type.name,
            songId: song.id,
            type: type,
            title: '${type.name} entry',
            authorId: 'user-1',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            midi: type == LabEntryType.midi ? pattern.toJson() : null,
          ),
        );
      }
      await pump(
        tester,
        const Scaffold(body: DrumPracticePanel(songId: 'song-1')),
      );
      expect(find.text('note entry'), findsNothing);
      expect(find.text('midi entry'), findsOneWidget);
      // The first saved pattern is loaded on open, no extra tap needed.
      expect(container.read(drumPracticeProvider).entryId, 'midi');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Play'))
            .onPressed,
        isNotNull,
      );
      expect(find.byType(DrumKitView), findsOneWidget);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(container.read(drumPracticeProvider).playing, isTrue);
      expect(player.playing, isTrue);
      expect(find.text('Stop'), findsOneWidget);
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();
      expect(container.read(drumPracticeProvider).speed, 0.5);
      expect(player.loadedBpm, 60);
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(container.read(drumPracticeProvider).playing, isFalse);
      expect(player.playing, isFalse);
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(player.playing, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sync with click defaults on and updates provider state', (
    tester,
  ) async {
    await pump(
      tester,
      const Scaffold(body: DrumPracticePanel(songId: 'song-1')),
    );
    final toggle = find.widgetWithText(SwitchListTile, 'Sync with click');
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(drumPracticeProvider).syncWithClick, isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('changing the panel song clears and stops the loaded pattern', (
    tester,
  ) async {
    await pump(
      tester,
      const Scaffold(body: DrumPracticePanel(songId: 'song-1')),
    );
    final practice = container.read(drumPracticeProvider.notifier);
    await practice.loadPattern('entry', pattern);
    await practice.start();
    expect(player.playing, isTrue);
    await pump(
      tester,
      const Scaffold(body: DrumPracticePanel(songId: 'song-2')),
    );
    expect(player.playing, isFalse);
    expect(container.read(drumPracticeProvider).pattern, isNull);
    expect(container.read(drumPracticeProvider).entryId, isNull);
    expect(find.byType(DrumKitView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('band viewers list scoped entries but cannot import', (
    tester,
  ) async {
    await pump(
      tester,
      const Scaffold(
        body: DrumPracticePanel(songId: 'song-1', bandId: 'band-1'),
      ),
    );
    expect(repo.watches, [('song-1', 'band-1')]);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.text('Save to Song Lab'), findsNothing);
  });

  for (final bandId in <String?>[null, 'band-1']) {
    testWidgets(
      'imports preview before saving in scope $bandId and reports malformed MIDI',
      (tester) async {
        canEditBand = true;
        const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
        var bytes = Uint8List.fromList([
          ...'MThd'.codeUnits,
          0,
          0,
          0,
          6,
          0,
          0,
          0,
          1,
          0,
          96,
          ...'MTrk'.codeUnits,
          0,
          0,
          0,
          8,
          0,
          0x99,
          36,
          100,
          0,
          0xff,
          0x2f,
          0,
        ]);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async => [
            {
              'name': 'beat.mid',
              'size': bytes.length,
              'bytes': bytes,
              'path': null,
            },
          ],
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await pump(
          tester,
          Scaffold(
            body: DrumPracticePanel(songId: 'song-1', bandId: bandId),
          ),
        );
        await tester.tap(find.text('Import .mid'));
        await tester.pumpAndSettle();
        expect(find.text('Preview: beat.mid'), findsOneWidget);
        expect(find.byType(DrumKitView), findsOneWidget);
        expect(repo.saved, isEmpty);
        await tester.ensureVisible(find.text('Save to Song Lab'));
        await tester.tap(find.text('Save to Song Lab'));
        await tester.pumpAndSettle();
        expect(repo.saved, hasLength(1));
        expect(repo.saved.single.type, LabEntryType.midi);
        expect(repo.saved.single.songId, 'song-1');
        expect(repo.saved.single.authorId, 'user-1');
        expect(repo.savedBandId, bandId);
        expect(repo.saved.single.bandId, bandId);
        expect(repo.saved.single.pattern!.hits.single.note, 36);
        expect(find.text('Save to Song Lab'), findsNothing);

        bytes = Uint8List.fromList([0]);
        await tester.ensureVisible(find.text('Import .mid'));
        await tester.tap(find.text('Import .mid'));
        await tester.pumpAndSettle();
        expect(find.text('Truncated MIDI data'), findsOneWidget);
        expect(repo.saved, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
