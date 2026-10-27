import 'dart:async';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import '../helpers/mocks.mocks.dart';

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
    var source = request.audioSourceMessage;
    if (source is ConcatenatingAudioSourceMessage) {
      source = source.children.single;
    }
    clip = source is ClippingAudioSourceMessage ? source : null;
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
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

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

  setUp(() {
    previousPlatform = JustAudioPlatform.instance;
    audio = _FakeJustAudio();
    JustAudioPlatform.instance = audio;
    repo = _InMemoryLabRepo();
    // Real-time pumps let the scaffold's connectivity stream subscribe.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labRepositoryProvider.overrideWithValue(repo),
          isDemoUserProvider.overrideWithValue(demo),
        ],
        child: MaterialApp(home: PracticeRegionsScreen(entry: entry)),
      ),
    );
    await settleAudio(tester);
  }

  testWidgets('renders two named regions without autoplay', (tester) async {
    await pump(tester, _entry());
    expect(find.text('Practice regions'), findsOneWidget);
    expect(find.text('Verse 2'), findsOneWidget);
    expect(find.text('Chorus'), findsOneWidget);
    expect(audio.players.values.single.playCalls, 0);
  });

  testWidgets('Split at ten seconds saves two regions and opens naming', (
    tester,
  ) async {
    await pump(tester, _entry(regions: const []));
    final player = audio.players.values.single;
    player
      ..position = const Duration(seconds: 10)
      ..emit();
    await settleAudio(tester);

    await tester.tap(find.text('Split'));
    await settleAudio(tester);
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.regions, hasLength(2));
    expect(repo.saved.single.regions[0].endMs, 10000);
    expect(repo.saved.single.regions[1].startMs, 10000);
    expect(find.text('Region name'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Chorus'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settleAudio(tester);
    expect(repo.saved.last.regions[1].name, 'Chorus');
  });

  testWidgets('selecting adjacent regions loops both names', (tester) async {
    await pump(tester, _entry());
    await tester.tap(find.byKey(const ValueKey('verse')));
    await settleAudio(tester);
    await tester.tap(find.byKey(const ValueKey('chorus')));
    await settleAudio(tester);
    expect(find.text('Looping Verse 2 → Chorus'), findsOneWidget);
    final player = audio.players.values.single;
    expect(player.clip?.start, Duration.zero);
    expect(player.clip?.end, const Duration(seconds: 20));
    expect(player.loopMode, LoopModeMessage.one);
    expect(repo.saved, isEmpty);
  });

  testWidgets('clip positions use file time and deselection clears the clip', (
    tester,
  ) async {
    await pump(tester, _entry());
    await tester.tap(find.byKey(const ValueKey('chorus')));
    await settleAudio(tester);
    final player = audio.players.values.single;
    player
      ..position = const Duration(seconds: 2)
      ..emit();
    await settleAudio(tester);
    expect(find.text('0:12 / 0:20'), findsOneWidget);
    expect(player.clip?.start, const Duration(seconds: 10));

    await tester.tap(find.byKey(const ValueKey('chorus')));
    await settleAudio(tester);
    expect(find.textContaining('Looping'), findsNothing);
    expect(player.clip, isNull);
    expect(player.loopMode, LoopModeMessage.off);
  });

  testWidgets('demo users can loop but cannot edit', (tester) async {
    await pump(tester, _entry(), demo: true);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Split'))
          .onPressed,
      isNull,
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.byKey(const ValueKey('verse')));
    await settleAudio(tester);
    expect(find.text('Looping Verse 2'), findsOneWidget);
    expect(repo.saved, isEmpty);
  });

  testWidgets('removing the grid saves null without losing regions', (
    tester,
  ) async {
    await pump(tester, _entry(grid: const AudioGrid(bpm: 120)));
    await tester.scrollUntilVisible(find.text('Remove grid'), 200);
    // The scaffold's bottom bar overlaps the end of the list in the test
    // viewport, so press the button directly.
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Remove grid'))
        .onPressed!();
    await settleAudio(tester);
    expect(repo.saved.single.grid, isNull);
    expect(repo.saved.single.regions, hasLength(2));
    expect(find.text('Set tempo grid'), findsOneWidget);
  });
}
