import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/models/metronome_session.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/repositories/metronome_session_repository.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/services/audio/audio_note_recorder.dart';
import 'package:flowgroove/services/audio/song_peaks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import '../helpers/mocks.mocks.dart';
import '../providers/backing_transport_test.dart'
    show FakeBackingEngine, FakeMetronome;

/// A platform player that loads instantly and reports a fixed duration, so the
/// screen can be built without any of just_audio's native plumbing.
class _FakeAudioPlayer extends AudioPlayerPlatform {
  _FakeAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  Duration position = Duration.zero;
  Duration loadedDuration = duration;
  ClippingAudioSourceMessage? clip;
  LoopModeMessage? loopMode;
  int playCalls = 0;
  int pauseCalls = 0;
  int loadCalls = 0;
  String? loadedUri;
  final calls = <String>[];

  static const duration = Duration(seconds: 20);

  void emit() => _events.add(
    PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: loadedDuration,
      duration: loadedDuration,
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ),
  );

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    loadCalls++;
    var source = request.audioSourceMessage;
    if (source is ConcatenatingAudioSourceMessage) {
      source = source.children.single;
    }
    clip = source is ClippingAudioSourceMessage ? source : null;
    calls.add(clip == null ? 'load' : 'setClip');
    final uriSource = clip?.child ?? source;
    loadedUri = uriSource is UriAudioSourceMessage ? uriSource.uri : null;
    loadedDuration = clip == null
        ? duration
        : (clip!.end ?? duration) - (clip!.start ?? Duration.zero);
    position = request.initialPosition ?? Duration.zero;
    // On a timer, not a microtask: the event stream is a broadcast stream and
    // just_audio subscribes after load() returns, so an immediate emit is
    // dropped and the load never resolves.
    Timer(const Duration(milliseconds: 5), emit);
    return LoadResponse(duration: loadedDuration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playCalls++;
    calls.add('play');
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    pauseCalls++;
    calls.add('pause');
    return PauseResponse();
  }

  // just_audio configures the player on every activation and the base class
  // throws for anything unimplemented, which would fail the load before it
  // starts. None of these affect what the screen shows.
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    loopMode = request.loopMode;
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    calls.add('seek');
    position = request.position ?? Duration.zero;
    emit();
    return SeekResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    unawaited(_events.close());
    return DisposeResponse();
  }
}

class _FakeJustAudio extends JustAudioPlatform {
  final players = <String, _FakeAudioPlayer>{};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      players[request.id] = _FakeAudioPlayer(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    players.remove(request.id);
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

class _SessionLog extends MetronomeSessionRepository {
  final saved = <MetronomeSession>[];

  @override
  Future<void> save(MetronomeSession session) async => saved.add(session);
}

/// In-memory stand-in so saves are observable without Firestore.
class _InMemoryLabRepo extends FirestoreLabRepository {
  // The base constructor resolves `.instance` when given nulls, which needs a
  // live Firebase app — hand it mocks instead.
  _InMemoryLabRepo()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  final saved = <SongLabEntry>[];
  final deleted = <String>[];

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async =>
      saved.add(entry);

  @override
  Future<void> deleteEntry(
    String songId,
    String entryId, {
    String? bandId,
  }) async => deleted.add(entryId);

  @override
  Stream<List<SongLabEntry>> watchEntries(String songId, {String? bandId}) =>
      const Stream.empty();
}

Int16List _clickTrack() {
  const sampleRate = 22050;
  final pcm = Int16List(sampleRate * 20);
  var beat = 0;
  for (
    var t = sampleRate * 300 ~/ 1000;
    t + 220 < pcm.length;
    t += sampleRate ~/ 2
  ) {
    final value = beat++ % 4 == 0 ? 30000 : 12000;
    for (var b = 0; b < 220; b++) {
      pcm[t + b] = b.isEven ? value : -value;
    }
  }
  return pcm;
}

const _regions = [
  AudioRegion(id: 'verse', name: 'Verse 2', startMs: 0, endMs: 10000),
  AudioRegion(id: 'chorus', name: 'Chorus', startMs: 10000, endMs: 20000),
];

SongLabEntry _entry({List<AudioRegion> regions = _regions, AudioGrid? grid}) =>
    SongLabEntry(
      id: 'e1',
      songId: '_inbox',
      type: LabEntryType.recording,
      authorId: 'u1',
      createdAt: DateTime(2026, 7, 28),
      updatedAt: DateTime(2026, 7, 28),
      attachmentIds: const ['https://example.com/take.wav'],
      regions: regions,
      grid: grid,
    );

void main() {
  late _FakeJustAudio audio;
  late _InMemoryLabRepo repo;
  late JustAudioPlatform previousPlatform;
  late List<String> fetched;
  late _SessionLog sessions;
  late FakeBackingEngine engine;

  setUp(() {
    final previousCache = PracticeRegionsScreen.cacheAudioFile;
    PracticeRegionsScreen.cacheAudioFile = (bytes, name) async => null;
    addTearDown(() => PracticeRegionsScreen.cacheAudioFile = previousCache);
    previousPlatform = JustAudioPlatform.instance;
    audio = _FakeJustAudio();
    JustAudioPlatform.instance = audio;
    repo = _InMemoryLabRepo();
    fetched = [];
    sessions = _SessionLog();
    engine = FakeBackingEngine();
  });

  tearDown(() => JustAudioPlatform.instance = previousPlatform);

  Future<void> settleAudio(WidgetTester tester) async {
    // just_audio activates its platform on real async gaps that fake time
    // never reaches, so let real time pass between frames.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    SongLabEntry entry, {
    bool demo = false,
    Uint8List? bytes,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labRepositoryProvider.overrideWithValue(repo),
          isDemoUserProvider.overrideWithValue(demo),
          metronomeSessionRepositoryProvider.overrideWithValue(sessions),
          backingEngineProvider.overrideWithValue(engine),
          metronomeProvider.overrideWith(FakeMetronome.new),
          audioBytesFetcherProvider.overrideWithValue((url) async {
            fetched.add(url);
            return bytes ?? Uint8List(0);
          }),
        ],
        child: MaterialApp(home: PracticeRegionsScreen(entry: entry)),
      ),
    );
    await settleAudio(tester);
  }

  Future<void> openMore(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await settleAudio(tester);
  }

  Future<void> selectRun(WidgetTester tester) async {
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('region-pad-verse'))),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(
      find.byKey(const ValueKey('region-pad-chorus')),
      pointer: 2,
    );
    await hold.up();
    await settleAudio(tester);
  }

  Finder timeline() => find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_RegionsPainter',
  );

  testWidgets('practice shows pads and discloses marker editing until Done', (
    tester,
  ) async {
    await pump(tester, _entry());
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Add marker'), findsNothing);
    expect(find.text('Snap to bar'), findsNothing);
    expect(find.byKey(const ValueKey('marker-handle-0')), findsNothing);
    await tester.tap(find.byTooltip('Edit sections'));
    await tester.pumpAndSettle();
    expect(find.text('Editing sections'), findsOneWidget);
    expect(find.text('Add marker'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(const ValueKey('marker-handle-0')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('Add marker'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('empty practice offers section setup to editors', (tester) async {
    await pump(tester, _entry(regions: const []));
    expect(find.text('No sections yet'), findsOneWidget);
    await tester.tap(find.text('Set up sections'));
    await tester.pumpAndSettle();
    expect(find.text('Add marker'), findsOneWidget);
  });

  testWidgets('Re-run setup shows the placeholder', (tester) async {
    await pump(tester, _entry());
    await openMore(tester, 'Re-run setup');
    expect(find.text('Setup wizard coming'), findsOneWidget);
  });

  testWidgets(
    'tapping a pad loops only Chorus and tapping again keeps playing',
    (tester) async {
      await pump(tester, _entry());
      final pads = tester.widget<GridView>(find.byType(GridView));
      expect(pads.shrinkWrap, isTrue);
      expect(pads.physics, isA<NeverScrollableScrollPhysics>());
      expect(
        (pads.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        4,
      );
      await tester.tap(find.text('Verse 2'));
      await settleAudio(tester);
      await tester.tap(find.text('Chorus'));
      await settleAudio(tester);
      expect(find.text('Looping Chorus'), findsOneWidget);
      final player = audio.players.values.single;
      expect(player.clip?.start, const Duration(seconds: 10));
      expect(player.clip?.end, const Duration(seconds: 20));
      expect(player.loopMode, LoopModeMessage.one);
      await tester.tap(find.byTooltip('Play'));
      await settleAudio(tester);
      await tester.tap(find.text('Chorus'));
      await settleAudio(tester);
      expect(find.textContaining('Looping'), findsNothing);
      expect(player.clip, isNull);
      expect(player.loopMode, LoopModeMessage.off);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(repo.saved, isEmpty);
    },
  );

  testWidgets(
    'holding Verse 2 and tapping Chorus loops the run for demo users',
    (tester) async {
      await pump(tester, _entry(), demo: true);
      final hold = await tester.startGesture(
        tester.getCenter(find.text('Verse 2')),
        pointer: 1,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Chorus'), pointer: 2);
      await settleAudio(tester);
      expect(find.text('Looping Verse 2 → Chorus'), findsOneWidget);
      final player = audio.players.values.single;
      expect(player.clip?.start, Duration.zero);
      expect(player.clip?.end, const Duration(seconds: 20));
      expect(player.loopMode, LoopModeMessage.one);
      await hold.up();
      await tester.pump();
      await tester.tap(find.text('Chorus'));
      await settleAudio(tester);
      expect(find.text('Looping Chorus'), findsOneWidget);
      expect(repo.saved, isEmpty);
    },
  );

  testWidgets('cached audio loads a local file and shares bytes with PCM', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    PracticeRegionsScreen.cacheAudioFile = (data, name) async {
      expect(data, same(bytes));
      expect(name, 'practice_e1.wav');
      return '/tmp/practice_e1.wav';
    };
    final previousDecode = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm =
        (data, {required sampleRate, required durationMs}) async {
          expect(data, same(bytes));
          return null;
        };
    addTearDown(() => PracticeRegionsScreen.decodePcm = previousDecode);
    const url = 'https://example.com/take.wav?token=test';
    await pump(tester, _entry().copyWith(attachmentIds: [url]), bytes: bytes);
    expect(
      audio.players.values.single.loadedUri,
      'file:///tmp/practice_e1.wav',
    );
    await tester.tap(find.byTooltip('Edit sections'));
    await settleAudio(tester);
    await tester.tap(find.byKey(const ValueKey('marker-handle-0')));
    await settleAudio(tester);
    expect(fetched, [url]);
  });

  testWidgets('a null cache path falls back to the URL', (tester) async {
    await pump(tester, _entry());
    expect(
      audio.players.values.single.loadedUri,
      'https://example.com/take.wav',
    );
  });

  testWidgets('Suggest tempo grid applies a 120 BPM click track grid', (
    tester,
  ) async {
    final previousDecode = PracticeRegionsScreen.decodePcm;
    var decodes = 0;
    PracticeRegionsScreen.decodePcm =
        (bytes, {required sampleRate, required durationMs}) async {
          decodes++;
          expect(sampleRate, 22050);
          expect(durationMs, 20000);
          return _clickTrack();
        };
    addTearDown(() => PracticeRegionsScreen.decodePcm = previousDecode);
    await pump(tester, _entry());
    expect(decodes, 0);
    await openMore(tester, 'Auto slice');
    await settleAudio(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Suggest tempo grid'));
    await settleAudio(tester);
    expect(find.textContaining('BPM · downbeat'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await settleAudio(tester);
    expect(repo.saved.single.grid!.bpm, closeTo(120, 0.5));
    expect(repo.saved.single.grid!.offsetMs, closeTo(300, 20));
    expect(repo.saved.single.grid!.beatsPerBar, 4);
    expect(repo.saved.single.regions, hasLength(2));
    await openMore(tester, 'Auto slice');
    await settleAudio(tester);
    expect(decodes, 1);
    expect(fetched, ['https://example.com/take.wav']);
    Navigator.of(tester.element(find.text('Apply'))).pop();
    await settleAudio(tester);
  });

  testWidgets('Slice every 4 bars previews and confirms replacing regions', (
    tester,
  ) async {
    final previousDecode = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm =
        (bytes, {required sampleRate, required durationMs}) async => null;
    addTearDown(() => PracticeRegionsScreen.decodePcm = previousDecode);
    const grid = AudioGrid(bpm: 120, offsetMs: 1000);
    await pump(tester, _entry(grid: grid));
    await openMore(tester, 'Auto slice');
    await settleAudio(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Slice every N bars'));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '4')).selected,
      isTrue,
    );
    expect(find.text('4 slices'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await settleAudio(tester);
    expect(find.text('Replace 2 regions?'), findsOneWidget);
    expect(repo.saved, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await settleAudio(tester);
    final regions = repo.saved.single.regions;
    expect(
      [for (final r in regions) (r.startMs, r.endMs)],
      [(0, 1000), (1000, 9000), (9000, 17000), (17000, 20000)],
    );
    for (final region in regions.skip(1)) {
      expect((region.startMs - grid.offsetMs) % 8000, 0);
    }
    expect(regions.first.name, 'Verse 2');
  });

  testWidgets(
    'transient slicing previews snapped cuts and can cancel replacement',
    (tester) async {
      final previousDecode = PracticeRegionsScreen.decodePcm;
      PracticeRegionsScreen.decodePcm =
          (bytes, {required sampleRate, required durationMs}) async =>
              _clickTrack();
      addTearDown(() => PracticeRegionsScreen.decodePcm = previousDecode);
      await pump(tester, _entry(grid: const AudioGrid(bpm: 120)));
      Future<void> preview() async {
        await openMore(tester, 'Auto slice');
        await settleAudio(tester);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Chop by transients'));
        await tester.pump();
        final slider = tester.widget<Slider>(find.byType(Slider).last);
        expect(slider.value, 1.5);
        expect(slider.min, 0.5);
        expect(slider.max, 3);
        slider.onChanged!(2);
        await tester.pump();
        expect(find.text('10 slices'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
        await settleAudio(tester);
      }

      await preview();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settleAudio(tester);
      expect(repo.saved, isEmpty);
      await preview();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await settleAudio(tester);
      final regions = repo.saved.single.regions;
      expect(regions, hasLength(10));
      expect(regions.first.startMs, 0);
      expect(regions.last.endMs, 20000);
      for (var i = 0; i < regions.length; i++) {
        expect(
          (regions[i].startMs, regions[i].endMs),
          (i * 2000, (i + 1) * 2000),
        );
      }
    },
  );

  testWidgets(
    'auto slice shows decoding progress and disables unavailable analysis',
    (tester) async {
      final previousDecode = PracticeRegionsScreen.decodePcm;
      final decoded = Completer<Int16List?>();
      PracticeRegionsScreen.decodePcm =
          (bytes, {required sampleRate, required durationMs}) => decoded.future;
      addTearDown(() => PracticeRegionsScreen.decodePcm = previousDecode);
      await pump(tester, _entry(regions: const []));
      await openMore(tester, 'Auto slice');
      await settleAudio(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      decoded.complete(null);
      await settleAudio(tester);
      expect(
        find.text('Audio could not be decoded for analysis.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Slice every N bars'));
      await tester.pump();
      expect(find.text('Set a tempo grid first.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      Navigator.of(tester.element(find.text('Apply'))).pop();
      await settleAudio(tester);
      expect(repo.saved, isEmpty);
    },
  );

  testWidgets('cache failures fall back to the URL', (tester) async {
    PracticeRegionsScreen.cacheAudioFile = (bytes, name) async =>
        throw StateError('cache unavailable');
    await pump(tester, _entry());
    expect(
      audio.players.values.single.loadedUri,
      'https://example.com/take.wav',
    );
  });

  testWidgets('selecting a region while playing pauses before reloading', (
    tester,
  ) async {
    await pump(tester, _entry());
    await tester.tap(find.byTooltip('Play'));
    await settleAudio(tester);
    final player = audio.players.values.single;
    player.calls.clear();
    await tester.tap(find.byKey(const ValueKey('region-pad-chorus')));
    await settleAudio(tester);
    expect(player.calls, ['pause', 'setClip', 'seek', 'play']);
    expect(player.position, Duration.zero);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('renders two named regions without autoplay', (tester) async {
    await pump(tester, _entry());
    expect(find.text('Practice regions'), findsOneWidget);
    expect(find.text('Verse 2'), findsOneWidget);
    expect(find.text('Chorus'), findsOneWidget);
    expect(audio.players.values.single.playCalls, 0);
  });

  testWidgets(
    'Add marker saves an unnamed boundary without interrupting play',
    (tester) async {
      // Snap to an exact boundary even as playback advances during settling.
      const grid = AudioGrid(bpm: 120, offsetMs: 240);
      await pump(tester, _entry(regions: const [], grid: grid));
      final player = audio.players.values.single;
      await tester.tap(find.byTooltip('Play'));
      await settleAudio(tester);
      player
        ..position = const Duration(seconds: 10)
        ..emit();
      await settleAudio(tester);

      await tester.tap(find.byTooltip('Edit sections'));
      await tester.pumpAndSettle();
      final loads = player.loadCalls;
      final pauses = player.pauseCalls;
      await tester.tap(find.text('Add marker'));
      await settleAudio(tester);
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.regions, hasLength(2));
      final boundaryMs = grid.snap(
        10000,
        durationMs: _FakeAudioPlayer.duration.inMilliseconds,
      );
      expect(repo.saved.single.regions[0].endMs, boundaryMs);
      expect(repo.saved.single.regions[1].startMs, boundaryMs);
      expect(repo.saved.single.regions[1].name, isEmpty);
      expect(find.byKey(const ValueKey('marker-handle-0')), findsOneWidget);
      expect(find.text('Region name'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(player.loadCalls, loads);
      expect(player.pauseCalls, pauses);

      final rect = tester.getRect(timeline());
      await tester.tapAt(Offset(rect.left + rect.width * .75, rect.center.dy));
      await settleAudio(tester);
      expect(find.text('Region name'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Chorus'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settleAudio(tester);
      expect(repo.saved.last.regions[1].name, 'Chorus');
    },
  );

  testWidgets('Fine-tune nudges M1 locally and saves on Done, decoding once', (
    tester,
  ) async {
    var decodes = 0;
    PracticeRegionsScreen.decodePcm =
        (bytes, {required sampleRate, required durationMs}) async {
          decodes++;
          expect(sampleRate, 44100);
          expect(durationMs, 20000);
          return Int16List.fromList(
            List.generate(
              sampleRate * durationMs ~/ 1000,
              (i) => i.isEven ? 1000 : -1000,
            ),
          );
        };
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodeSongPcm);
    await pump(tester, _entry());
    await tester.tap(find.byTooltip('Edit sections'));
    await settleAudio(tester);
    await tester.tap(find.byKey(const ValueKey('marker-handle-0')));
    await settleAudio(tester);
    expect(find.text('Fine-tune M1'), findsOneWidget);
    await tester.ensureVisible(find.text('+10 ms'));
    await tester.tap(find.text('+10 ms'));
    await tester.pump();
    await tester.ensureVisible(find.text('+10 ms'));
    await tester.tap(find.text('+10 ms'));
    await tester.pump();
    expect(find.text('00:10.020'), findsOneWidget);
    expect(repo.saved, isEmpty);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Done'));
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settleAudio(tester);
    expect(repo.saved.single.regions[0].endMs, 10020);
    expect(repo.saved.single.regions[1].startMs, 10020);

    await tester.tap(find.byKey(const ValueKey('marker-handle-0')));
    await settleAudio(tester);
    expect(decodes, 1);
    expect(fetched, ['https://example.com/take.wav']);
    await tester.ensureVisible(find.text('+10 ms'));
    await tester.tap(find.text('+10 ms'));
    await tester.pump();
    // Dismissing the sheet discards its local preview.
    Navigator.of(
      tester.element(find.widgetWithText(FilledButton, 'Done')),
    ).pop();
    await settleAudio(tester);
    expect(repo.saved, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('marker-handle-0')));
    await settleAudio(tester);
    expect(find.text('00:10.020'), findsOneWidget);
    Navigator.of(
      tester.element(find.widgetWithText(FilledButton, 'Done')),
    ).pop();
    await settleAudio(tester);
  });

  testWidgets('Fine-tune jog wheel moves clockwise and saves on Done', (
    tester,
  ) async {
    final previousDecode = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm =
        (bytes, {required sampleRate, required durationMs}) async => null;
    addTearDown(() => PracticeRegionsScreen.decodePcm = previousDecode);
    await pump(tester, _entry());
    await tester.tap(find.byTooltip('Edit sections'));
    await settleAudio(tester);
    await tester.tap(find.byKey(const ValueKey('marker-handle-0')));
    await settleAudio(tester);
    final wheel = find.byKey(const ValueKey('marker-jog-wheel'));
    await tester.ensureVisible(wheel);
    final center = tester.getCenter(wheel);
    final gesture = await tester.startGesture(center + const Offset(0, -65));
    for (var i = 1; i <= 12; i++) {
      final angle = i * math.pi / 24;
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(
        center + Offset(math.sin(angle) * 65, -math.cos(angle) * 65),
        timeStamp: Duration(milliseconds: i * 100),
      );
    }
    await gesture.up();
    await settleAudio(tester);
    expect(repo.saved, isEmpty);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Done'));
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settleAudio(tester);
    final delta = repo.saved.single.regions[0].endMs - 10000;
    expect(delta, greaterThan(0));
    expect(delta, lessThan(100));
    expect(repo.saved.single.regions[1].startMs, 10000 + delta);
  });

  testWidgets('Fine-tune stays available when PCM decoding fails', (
    tester,
  ) async {
    PracticeRegionsScreen.decodePcm =
        (bytes, {required sampleRate, required durationMs}) async => null;
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodeSongPcm);
    await pump(tester, _entry());
    await tester.tap(find.byTooltip('Edit sections'));
    await settleAudio(tester);
    await tester.tap(find.byKey(const ValueKey('marker-handle-0')));
    await settleAudio(tester);
    final snap = tester.widget<SegmentedButton<BoundarySnap>>(
      find.byType(SegmentedButton<BoundarySnap>),
    );
    expect(
      snap.segments
          .where((s) => s.value != BoundarySnap.off)
          .every((s) => !s.enabled),
      isTrue,
    );
    await tester.ensureVisible(find.text('+1 ms'));
    await tester.tap(find.text('+1 ms'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Done'));
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settleAudio(tester);
    expect(repo.saved.single.regions[0].endMs, 10001);
  });

  testWidgets(
    'Audition clears the selected loop and pauses after two seconds',
    (tester) async {
      PracticeRegionsScreen.decodePcm =
          (bytes, {required sampleRate, required durationMs}) async => null;
      addTearDown(() => PracticeRegionsScreen.decodePcm = decodeSongPcm);
      await pump(tester, _entry());
      await tester.tap(find.byKey(const ValueKey('region-pad-chorus')));
      await settleAudio(tester);
      await tester.tap(find.byTooltip('Edit sections'));
      await settleAudio(tester);
      await tester.tap(find.byKey(const ValueKey('marker-handle-0')));
      await settleAudio(tester);
      final player = audio.players.values.single;
      final plays = player.playCalls;
      await tester.ensureVisible(find.text('Audition'));
      await tester.tap(find.text('Audition'));
      await settleAudio(tester);
      expect(player.clip, isNull);
      expect(player.loopMode, LoopModeMessage.off);
      expect(player.position, const Duration(seconds: 9));
      expect(player.playCalls, plays + 1);
      final pauses = player.pauseCalls;
      await tester.pump(const Duration(seconds: 2));
      await settleAudio(tester);
      expect(player.pauseCalls, pauses + 1);
      expect(repo.saved, isEmpty);
      Navigator.of(
        tester.element(find.widgetWithText(FilledButton, 'Done')),
      ).pop();
      await settleAudio(tester);
    },
  );

  testWidgets('practice timeline seeks outside the loop and clears the clip', (
    tester,
  ) async {
    await pump(
      tester,
      _entry(
        regions: const [
          AudioRegion(id: 'intro', name: 'Intro', startMs: 0, endMs: 5000),
          AudioRegion(id: 'verse', name: 'Verse', startMs: 5000, endMs: 10000),
          AudioRegion(
            id: 'chorus',
            name: 'Chorus',
            startMs: 10000,
            endMs: 20000,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('region-pad-chorus')));
    await settleAudio(tester);
    final rect = tester.getRect(timeline());
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
    await settleAudio(tester);
    final player = audio.players.values.single;
    expect(player.clip, isNull);
    expect(player.loopMode, LoopModeMessage.off);
    expect(player.position, const Duration(seconds: 5));
    expect(find.textContaining('Looping'), findsNothing);
    expect(repo.saved, isEmpty);
  });

  testWidgets('practice timeline seeks within a section without selecting it', (
    tester,
  ) async {
    await pump(tester, _entry());
    final rect = tester.getRect(timeline());
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
    await settleAudio(tester);
    final player = audio.players.values.single;
    expect(player.position, const Duration(seconds: 5));
    expect(player.clip, isNull);
    expect(find.textContaining('Looping'), findsNothing);
    expect(repo.saved, isEmpty);
  });

  testWidgets('selecting adjacent regions loops both names', (tester) async {
    await pump(tester, _entry());
    await selectRun(tester);
    expect(find.text('Looping Verse 2 → Chorus').hitTestable(), findsOneWidget);
    final player = audio.players.values.single;
    expect(player.clip?.start, Duration.zero);
    expect(player.clip?.end, const Duration(seconds: 20));
    expect(player.loopMode, LoopModeMessage.one);
    expect(player.playCalls, 0);
    expect(player.pauseCalls, 0);
    expect(repo.saved, isEmpty);
  });

  testWidgets('clip positions use file time and deselection clears the clip', (
    tester,
  ) async {
    await pump(tester, _entry());
    await tester.tap(find.byKey(const ValueKey('region-pad-chorus')));
    await settleAudio(tester);
    final player = audio.players.values.single;
    player
      ..position = const Duration(seconds: 2)
      ..emit();
    await settleAudio(tester);
    expect(find.text('0:12 / 0:20'), findsOneWidget);
    expect(player.clip?.start, const Duration(seconds: 10));

    await tester.tap(find.byKey(const ValueKey('region-pad-chorus')));
    await settleAudio(tester);
    expect(find.textContaining('Looping'), findsNothing);
    expect(player.clip, isNull);
    expect(player.loopMode, LoopModeMessage.off);
  });

  testWidgets('demo viewers see no pencil or overflow and can loop', (
    tester,
  ) async {
    await pump(tester, _entry(), demo: true);
    expect(find.byTooltip('Edit sections'), findsNothing);
    expect(find.byTooltip('More'), findsNothing);
    expect(find.text('Add marker'), findsNothing);
    expect(find.byKey(const ValueKey('marker-handle-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('region-pad-verse')));
    await settleAudio(tester);
    expect(find.text('Looping Verse 2').hitTestable(), findsOneWidget);
    expect(repo.saved, isEmpty);
  });

  testWidgets('Edit handles still drag and save boundaries', (tester) async {
    await pump(tester, _entry());
    await tester.tap(find.byTooltip('Edit sections'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('marker-handle-0')),
      const Offset(60, 0),
    );
    await settleAudio(tester);
    expect(repo.saved, hasLength(1));
    final regions = repo.saved.single.regions;
    expect(regions.first.endMs, greaterThan(10000));
    expect(regions.first.endMs, regions.last.startMs);
  });

  testWidgets('Tempo grid menu keeps downbeat editing in the dialog', (
    tester,
  ) async {
    await pump(tester, _entry(grid: const AudioGrid(bpm: 120)));
    expect(find.text('Tempo grid'), findsNothing);
    await openMore(tester, 'Tempo grid');
    await tester.tap(find.text('+10 ms'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settleAudio(tester);
    expect(repo.saved.single.grid!.offsetMs, 10);
    expect(repo.saved.single.regions, hasLength(2));
  });

  testWidgets('Click & drums is disabled without a whole-BPM grid', (
    tester,
  ) async {
    await pump(tester, _entry(grid: const AudioGrid(bpm: 120.5)));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Click & drums'))
          .onPressed,
      isNull,
    );
    expect(find.byTooltip('Needs a whole-number BPM grid'), findsOneWidget);
  });

  testWidgets('removing the grid saves null without losing regions', (
    tester,
  ) async {
    await pump(tester, _entry(grid: const AudioGrid(bpm: 120)));
    await openMore(tester, 'Tempo grid');
    await tester.tap(find.widgetWithText(TextButton, 'Remove grid'));
    await settleAudio(tester);
    expect(repo.saved.single.grid, isNull);
    expect(repo.saved.single.regions, hasLength(2));
    await tester.tap(find.byTooltip('Edit sections'));
    await tester.pumpAndSettle();
    expect(find.text('Snap to bar'), findsNothing);
  });

  testWidgets('an imported file without peaks gets a waveform, once', (
    tester,
  ) async {
    final pcm = ByteData(16000 * 2);
    for (var i = 0; i < 16000; i++) {
      pcm.setInt16(i * 2, i.isEven ? 16000 : -16000, Endian.little);
    }
    await pump(
      tester,
      _entry(),
      bytes: wavFromPcm16(pcm.buffer.asUint8List(), sampleRate: 16000),
    );
    expect(fetched, ['https://example.com/take.wav']);
    expect(repo.saved.single.peaks, isNotEmpty);
    expect(repo.saved.single.regions, hasLength(2));
  });

  testWidgets('a practised loop is logged with its name and passes', (
    tester,
  ) async {
    PracticeRegionsScreen.minLoggedMs = 0;
    addTearDown(() => PracticeRegionsScreen.minLoggedMs = 10000);
    await pump(tester, _entry());
    await selectRun(tester);
    await tester.tap(find.byTooltip('Play'));
    await settleAudio(tester);
    final player = audio.players.values.single;
    for (final ms in [15000, 1000, 15000, 500]) {
      player
        ..position = Duration(milliseconds: ms)
        ..emit();
      await settleAudio(tester);
    }
    // Shrinking the run ends this loop's session.
    await tester.tap(find.byKey(const ValueKey('region-pad-chorus')));
    await settleAudio(tester);
    final logged = sessions.saved.single;
    expect(logged.regionName, 'Verse 2 → Chorus');
    expect(logged.loopReps, 2);
    expect(logged.songId, isNull); // inbox takes have no song
  });

  testWidgets('click & drums mode loops a region on the bar grid', (
    tester,
  ) async {
    final decoded = <int>[];
    PracticeRegionsScreen.decodePcm =
        (bytes, {required sampleRate, required durationMs}) async {
          decoded.add(sampleRate);
          return Int16List(sampleRate * durationMs ~/ 1000);
        };
    addTearDown(() => PracticeRegionsScreen.decodePcm = decodeSongPcm);
    await pump(tester, _entry(grid: const AudioGrid(bpm: 120)));
    final toggle = find.widgetWithText(TextButton, 'Click & drums');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await settleAudio(tester);
    expect(decoded, hasLength(1));
    expect(fetched, ['https://example.com/take.wav']);
    expect(engine.loads.single.names, ['Song']);

    await tester.tap(find.byKey(const ValueKey('region-pad-chorus')));
    await settleAudio(tester);
    expect(engine.commands, isEmpty); // selecting doesn't start playback
    await tester.ensureVisible(find.byTooltip('Play'));
    await tester.tap(find.byTooltip('Play'));
    await settleAudio(tester);
    final launch = engine.commands.single;
    expect(launch.kind, BackingKind.launch);
    expect((launch.fromBar, launch.bars, launch.loop), (5, 5, true));
  });
}
