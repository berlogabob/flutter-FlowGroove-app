import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/metronome_session.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/providers/practice_stats_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/repositories/metronome_session_repository.dart';
import 'package:flowgroove/screens/practice_regions_screen.dart';
import 'package:flowgroove/services/audio/audio_file_cache.dart';
import 'package:flowgroove/services/audio/audio_note_edit.dart';
import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flowgroove/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart'
    show SharePlatform;

import '../helpers/mocks.mocks.dart';
import '../providers/backing_transport_test.dart'
    show FakeBackingEngine, FakeMetronome;

class _FakeAudioPlayer extends AudioPlayerPlatform {
  _FakeAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  Duration position = Duration.zero;
  Duration loadedDuration = duration;
  static Duration sourceDuration = duration;
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
        ? sourceDuration
        : (clip!.end ?? sourceDuration) - (clip!.start ?? Duration.zero);
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
    // just_audio closes its subjects next; an open event stream makes that throw.
    await players.remove(request.id)?._events.close();
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

class _EditStorage extends StorageService {
  String? suffix;
  final uploads =
      <
        ({
          String entryId,
          String? suffix,
          Uint8List bytes,
          String ext,
          String contentType,
        })
      >[];

  @override
  Future<String> uploadLabAudio(
    Uint8List bytes, {
    required String? bandId,
    required String songId,
    required String entryId,
    String? objectSuffix,
    String ext = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    suffix = objectSuffix;
    uploads.add((
      entryId: entryId,
      suffix: objectSuffix,
      bytes: bytes,
      ext: ext,
      contentType: contentType,
    ));
    _FakeAudioPlayer.sourceDuration = Duration(
      milliseconds: audioDurationMs(bytes) ?? 20000,
    );
    return 'https://storage.test/o/new.wav?upload=${uploads.length}';
  }
}

class _PendingDeletes extends PendingStorageDeletes {
  _PendingDeletes(this.repo);
  final _InMemoryLabRepo repo;
  final queued = <String>[];
  final flushed = <String>[];

  @override
  Future<void> enqueue(String url) async {
    expect(
      repo.deleted.isNotEmpty ||
          repo.saved.last.attachmentIds.first.contains('new.wav'),
      isTrue,
    );
    expect(repo.saveAck?.isCompleted ?? true, isTrue);
    queued.add(url);
  }

  @override
  Future<void> flush(String url) async => flushed.add(url);
}

/// In-memory stand-in so saves are observable without Firestore.
class _InMemoryLabRepo extends FirestoreLabRepository {
  // The base constructor resolves `.instance` when given nulls, which needs a
  // live Firebase app — hand it mocks instead.
  _InMemoryLabRepo()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  Completer<void>? saveAck;
  bool failReplacementSave = false;
  final saved = <SongLabEntry>[];
  final deleted = <String>[];

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    saved.add(entry);
    await saveAck?.future;
    if (failReplacementSave && entry.id == 'e1') {
      throw StateError('save failed');
    }
  }

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

const _url =
    'https://firebasestorage.googleapis.com/v0/b/x/o/a%2Fb%2Fc.wav?alt=media&token=t';

SongLabEntry _entry({
  String? body,
  List<int> peaks = const [],
  bool peaksRms = true,
  String? url,
  List<AudioMarker> notes = const [],
  List<AudioRegion> regions = const [],
  AudioGrid? grid,
}) => SongLabEntry(
  id: 'e1',
  songId: '_inbox',
  type: LabEntryType.recording,
  authorId: 'u1',
  createdAt: DateTime(2026, 7, 28),
  updatedAt: DateTime(2026, 7, 28),
  title: 'Bridge riff',
  body: body,
  notes: notes,
  regions: regions,
  grid: grid,
  attachmentIds: [url ?? _url],
  peaks: peaks,
  peaksRms: peaksRms,
);

List<int> get _peaks => List.generate(200, (i) => i % 256);

class _SessionLog extends MetronomeSessionRepository {
  @override
  Future<void> save(MetronomeSession session) async {}
}

class _SharePlatform extends SharePlatform {
  final shared = <ShareParams>[];
  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return ShareResult.unavailable;
  }
}

void main() {
  final share = _SharePlatform();
  late JustAudioPlatform previousAudio;
  late SharePlatform previousShare;
  final defaultAudioFileCache = audioFileCache;
  setUp(() => audioFileCache = (_, _) async => null);
  tearDown(() => audioFileCache = defaultAudioFileCache);

  late _FakeJustAudio audio;
  late _InMemoryLabRepo repo;
  late List<String> fetched;
  late _EditStorage storage;
  late _PendingDeletes pending;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousAudio = JustAudioPlatform.instance;
    previousShare = SharePlatform.instance;
    SharePlatform.instance = share;
    share.shared.clear();
    _FakeAudioPlayer.sourceDuration = _FakeAudioPlayer.duration;
    audio = _FakeJustAudio();
    JustAudioPlatform.instance = audio;
    repo = _InMemoryLabRepo();
    fetched = [];
    storage = _EditStorage();
    pending = _PendingDeletes(repo);
  });

  tearDown(() {
    JustAudioPlatform.instance = previousAudio;
    SharePlatform.instance = previousShare;
  });

  Future<void> settleAudio(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openMore(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await settleAudio(tester);
  }

  Future<void> pump(
    WidgetTester tester,
    SongLabEntry entry, {
    Uint8List? bytes,
    bool demo = false,
    String? bandId,
    bool bandEditor = true,
    GoRouter? router,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labRepositoryProvider.overrideWithValue(repo),
          isDemoUserProvider.overrideWithValue(demo),
          if (bandId != null)
            canEditBandProvider(bandId).overrideWithValue(bandEditor),
          songsProvider.overrideWith(
            (ref) => throw StateError('Inbox must not look up songs'),
          ),
          metronomeSessionRepositoryProvider.overrideWithValue(_SessionLog()),
          backingEngineProvider.overrideWithValue(FakeBackingEngine()),
          metronomeProvider.overrideWith(FakeMetronome.new),
          storageServiceProvider.overrideWithValue(storage),
          pendingStorageDeletesProvider.overrideWithValue(pending),
          audioBytesFetcherProvider.overrideWithValue((url) async {
            fetched.add(url);
            return bytes ?? Uint8List(0);
          }),
        ],
        child: router == null
            ? MaterialApp(
                home: PracticeRegionsScreen(entry: entry, bandId: bandId),
              )
            : MaterialApp.router(routerConfig: router),
      ),
    );
    await settleAudio(tester);
  }

  testWidgets('renders the take title and a transport readout', (tester) async {
    await pump(tester, _entry(peaks: _peaks));
    expect(find.text('Bridge riff'), findsOneWidget);
    expect(find.textContaining(' / '), findsOneWidget);
  });

  testWidgets('play is disabled until a duration is known', (tester) async {
    _FakeAudioPlayer.sourceDuration = Duration.zero;
    await pump(tester, _entry(peaks: _peaks));
    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('play'))).onPressed,
      isNull,
    );
  });

  testWidgets('lists markers parsed from the body, in time order', (
    tester,
  ) async {
    await pump(
      tester,
      _entry(peaks: _peaks, body: '01:15 tempo drops\n00:04 chorus entry'),
    );
    expect(find.text('chorus entry'), findsOneWidget);
    expect(find.text('tempo drops'), findsOneWidget);

    final rows = tester.widgetList<Text>(find.byType(Text)).toList();
    final chorus = rows.indexWhere((t) => t.data == 'chorus entry');
    final tempo = rows.indexWhere((t) => t.data == 'tempo drops');
    expect(chorus, lessThan(tempo), reason: '0:04 sorts before 1:15');
  });

  testWidgets('adding a note keeps prose and moves legacy notes to the field', (
    tester,
  ) async {
    // Opening a short inbox take goes straight to listening at 0.
    await pump(tester, _entry(peaks: _peaks, body: 'Capo 2\n00:04 old'));
    await tester.tap(find.text('at 0:00'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'new');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.body, 'Capo 2');
    expect(repo.saved.single.notes, [
      (ms: 0, text: 'new'),
      (ms: 4000, text: 'old'),
    ]);
    expect(repo.saved.single.toJson()['notes'], [
      {'ms': 0, 'text': 'new'},
      {'ms': 4000, 'text': 'old'},
    ]);
  });

  testWidgets('deleting the last structured note keeps free text', (
    tester,
  ) async {
    await pump(
      tester,
      _entry(
        peaks: _peaks,
        body: 'Capo 2\n00:04 legacy',
        notes: [(ms: 4425, text: 'precise')],
      ),
    );
    expect(find.text('legacy'), findsNothing);
    await tester.tap(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('precise'),
              matching: find.byType(ListTile),
            ),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(repo.saved.single.body, 'Capo 2');
    expect(repo.saved.single.notes, isEmpty);
    expect(find.textContaining('No notes yet'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no markers', (
    tester,
  ) async {
    await pump(tester, _entry(peaks: _peaks));
    expect(find.textContaining('No notes yet'), findsOneWidget);
  });

  testWidgets('without peaks, offers a seek slider and waveform explanation', (
    tester,
  ) async {
    await pump(tester, _entry(url: 'https://x/y.m4a?alt=media&token=t'));
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('No waveform for this take'), findsOneWidget);
    expect(find.textContaining('Save trim'), findsNothing);
  });

  testWidgets('with peaks, draws a waveform instead of a slider', (
    tester,
  ) async {
    await pump(tester, _entry(peaks: _peaks));
    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('No waveform'), findsNothing);
  });

  testWidgets('a fresh take needs no byte fetch to draw', (tester) async {
    await pump(tester, _entry(peaks: _peaks));
    expect(fetched, isEmpty, reason: 'peaks come off the doc, not the audio');
  });

  testWidgets('backfills peaks for a legacy WAV take, once', (tester) async {
    // A one-second 8kHz WAV at half scale.
    final pcm = Uint8List(8000 * 2);
    final view = ByteData.sublistView(pcm);
    for (var i = 0; i < 8000; i++) {
      view.setInt16(i * 2, 16384, Endian.little);
    }
    await pump(tester, _entry(peaksRms: false), bytes: _buildWav(pcm));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(fetched, [_url], reason: 'fetched exactly once');
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.peaks, isNotEmpty);
    expect(repo.saved.single.peaksRms, isTrue);
  });

  testWidgets('does not backfill a take that already has RMS peaks', (
    tester,
  ) async {
    await pump(tester, _entry(peaks: _peaks), bytes: Uint8List(0));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(fetched, isEmpty);
    expect(repo.saved, isEmpty);
  });

  test('RMS peak metadata defaults, round-trips and survives copyWith', () {
    final legacy = SongLabEntry.fromJson(
      {..._entry(peaks: _peaks).toJson()}..remove('peaksRms'),
    );
    expect(legacy.peaksRms, isFalse);
    expect(legacy.toJson().containsKey('peaksRms'), isFalse);
    final updated = legacy.copyWith(peaksRms: true);
    expect(updated.toJson()['peaksRms'], isTrue);
    expect(SongLabEntry.fromJson(updated.toJson()).peaksRms, isTrue);
    expect(updated.copyWith(title: 'Renamed').peaksRms, isTrue);
    expect(updated.copyWith(peaksRms: false).peaksRms, isFalse);
  });

  for (final viewer in [false, true]) {
    testWidgets(
      'replaces legacy max peaks with RMS bars for ${viewer ? 'viewers locally' : 'editors persistently'}',
      (tester) async {
        final pcm = Uint8List(8000 * 2);
        final view = ByteData.sublistView(pcm);
        for (var i = 0; i < 8000; i++) {
          if (i >= 4000 || i % 40 == 0) {
            view.setInt16(i * 2, 32767, Endian.little);
          }
        }
        final bytes = _buildWav(pcm);
        final expected = peaksFromWav(bytes)!;
        final legacy = List.filled(expected.length, 255);
        await pump(
          tester,
          _entry(peaks: legacy, peaksRms: false),
          bytes: bytes,
          bandId: viewer ? 'band1' : null,
          bandEditor: !viewer,
        );
        expect(fetched, [_url]);
        if (viewer) {
          expect(repo.saved, isEmpty);
          final dynamic painter = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .firstWhere(
                (paint) =>
                    paint.painter.runtimeType.toString() == '_RegionsPainter',
              )
              .painter;
          // ignore: avoid_dynamic_calls
          final displayed = painter.entry as SongLabEntry;
          expect(displayed.peaks, expected);
          expect(displayed.peaksRms, isTrue);
        } else {
          expect(repo.saved.single.peaks, expected);
          expect(repo.saved.single.peaks, isNot(legacy));
          expect(repo.saved.single.peaksRms, isTrue);
        }
      },
    );
  }

  testWidgets('a marker row is tappable', (tester) async {
    await pump(tester, _entry(peaks: _peaks, body: '00:05 chorus entry'));
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('chorus entry'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNotNull);
    await tester.tap(find.text('chorus entry'));
    await settleAudio(tester);
    expect(audio.players.values.single.position, const Duration(seconds: 5));
  });

  testWidgets('deleting a marker updates before the save is acknowledged', (
    tester,
  ) async {
    final ack = repo.saveAck = Completer<void>();
    addTearDown(() {
      if (!ack.isCompleted) ack.complete();
    });
    await pump(
      tester,
      _entry(peaks: _peaks, body: '00:05 chorus entry\n00:12 tempo drops'),
    );
    await tester.tap(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('chorus entry'),
              matching: find.byType(ListTile),
            ),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.body, '');
    expect(repo.saved.single.notes, [(ms: 12000, text: 'tempo drops')]);
    expect(ack.isCompleted, false);
    expect(find.text('chorus entry'), findsNothing);
    expect(find.text('tempo drops'), findsOneWidget);
    ack.complete();
    await tester.pump();
  });

  testWidgets('title saves on submit and tap outside, including clearing it', (
    tester,
  ) async {
    await pump(tester, _entry(peaks: _peaks));
    final title = find.byKey(const ValueKey('recording-title'));
    await tester.enterText(title, '  New title  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.saved.last.title, 'New title');
    await tester.enterText(title, 'Outside');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(repo.saved.last.title, 'Outside');
    await tester.enterText(title, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.saved.last.title, '');
  });

  testWidgets('short inbox opens for listening with no setup or autoplay', (
    tester,
  ) async {
    await pump(tester, _entry(peaks: _peaks));
    expect(find.text('Set up for practice'), findsNothing);
    expect(audio.players.values.single.playCalls, 0);
    expect(find.text('Set up sections'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play')));
    await settleAudio(tester);
    expect(audio.players.values.single.playCalls, 1);
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play')));
    await settleAudio(tester);
    expect(audio.players.values.single.pauseCalls, 1);
  });

  testWidgets('menu adds an ms-precise note, replacing only the same second', (
    tester,
  ) async {
    await pump(
      tester,
      _entry(
        peaks: _peaks,
        body: 'Capo 2',
        notes: const [(ms: 11005, text: 'old'), (ms: 12000, text: 'keep')],
      ),
    );
    audio.players.values.single
      ..position = const Duration(milliseconds: 11425)
      ..emit();
    await settleAudio(tester);
    await openMore(tester, 'Add note at playhead');
    await tester.enterText(find.byType(TextField).last, 'precise');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.body, 'Capo 2');
    expect(repo.saved.single.notes, [
      (ms: 11425, text: 'precise'),
      (ms: 12000, text: 'keep'),
    ]);
    expect(repo.saved.single.regions, isEmpty);
    final dynamic ticks = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('note-ticks')))
        .painter;
    // ignore: avoid_dynamic_calls
    expect(ticks.markers, repo.saved.single.notes);
  });

  testWidgets(
    'note seek leaves a region loop to reach the original file time',
    (tester) async {
      await pump(
        tester,
        _entry(
          peaks: _peaks,
          regions: const [
            AudioRegion(id: 'a', name: 'Verse', startMs: 0, endMs: 10000),
            AudioRegion(id: 'b', name: 'Chorus', startMs: 10000, endMs: 20000),
          ],
          notes: const [(ms: 4425, text: 'earlier')],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('region-pad-b')));
      await settleAudio(tester);
      expect(
        audio.players.values.single.clip?.start,
        const Duration(seconds: 10),
      );
      await tester.ensureVisible(find.text('earlier'));
      await tester.tap(find.text('earlier'));
      await settleAudio(tester);
      expect(audio.players.values.single.clip, isNull);
      expect(
        audio.players.values.single.position,
        const Duration(milliseconds: 4425),
      );
      expect(repo.saved, isEmpty);
    },
  );

  testWidgets('editing a slice keeps time-based notes and ticks unchanged', (
    tester,
  ) async {
    await pump(
      tester,
      _entry(
        peaks: _peaks,
        regions: const [
          AudioRegion(id: 'a', name: 'Verse', startMs: 0, endMs: 10000),
          AudioRegion(id: 'b', name: 'Chorus', startMs: 10000, endMs: 20000),
        ],
        notes: const [(ms: 4425, text: 'independent')],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('shift')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('region-pad-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete slice'));
    await settleAudio(tester);
    expect(repo.saved.last.notes, [(ms: 4425, text: 'independent')]);
    final dynamic ticks = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('note-ticks')))
        .painter;
    // ignore: avoid_dynamic_calls
    expect(ticks.markers, repo.saved.last.notes);
  });

  testWidgets('note seek leaves click & drums and uses the precise file time', (
    tester,
  ) async {
    final previousDecode = PracticeRegionsScreen.decodePcm;
    PracticeRegionsScreen.decodePcm =
        (bytes, {required sampleRate, required durationMs}) async =>
            Int16List(sampleRate * durationMs ~/ 1000);
    addTearDown(() => PracticeRegionsScreen.decodePcm = previousDecode);
    await pump(
      tester,
      _entry(
        peaks: _peaks,
        grid: const AudioGrid(bpm: 120),
        notes: const [(ms: 4425, text: 'listen here')],
      ),
    );
    await tester.longPress(find.byKey(const ValueKey('play')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Click & drums'));
    await settleAudio(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('listen here'));
    await settleAudio(tester);
    expect(
      audio.players.values.single.position,
      const Duration(milliseconds: 4425),
    );
    expect(find.text('0:04 / 0:20'), findsOneWidget);
  });

  testWidgets(
    'split uses absolute playhead and crops each half with its own notes',
    (tester) async {
      const grid = AudioGrid(bpm: 120, offsetMs: 300);
      final entry = _entry(
        peaks: _peaks,
        body: 'Capo 2',
        grid: grid,
        regions: const [
          AudioRegion(id: 'a', name: 'Verse', startMs: 0, endMs: 10000),
          AudioRegion(id: 'b', name: 'Chorus', startMs: 10000, endMs: 20000),
        ],
        notes: const [
          (ms: 4425, text: 'first'),
          (ms: 12000, text: 'cut'),
          (ms: 15425, text: 'rest'),
        ],
      );
      await pump(tester, entry, bytes: _buildWav(Uint8List(20 * 16000)));
      await tester.tap(find.byKey(const ValueKey('region-pad-b')));
      await settleAudio(tester);
      audio.players.values.single
        ..position = const Duration(seconds: 2)
        ..emit();
      await settleAudio(tester);
      await openMore(tester, 'Split at playhead');
      expect(find.text('Split at 0:12?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Split'));
      await settleAudio(tester);
      expect(storage.uploads, hasLength(2));
      expect(
        storage.uploads.every((u) => u.suffix?.isNotEmpty == true),
        isTrue,
      );
      final rest = repo.saved.first;
      final first = repo.saved.last;
      expect(first.id, 'e1');
      expect(rest.id, isNot('e1'));
      expect(rest.title, 'Bridge riff (2)');
      expect(first.notes, [(ms: 4425, text: 'first')]);
      expect(rest.notes, [(ms: 0, text: 'cut'), (ms: 3425, text: 'rest')]);
      expect(first.body, 'Capo 2');
      expect(rest.body, 'Capo 2');
      expect(first.peaksRms, isTrue);
      expect(rest.peaksRms, isTrue);
      expect(first.peaks, trimPeaks(_peaks, 0, .6));
      expect(rest.peaks, trimPeaks(_peaks, .6, 1));
      expect(first.regions.last.endMs, 12000);
      expect(rest.regions.single.startMs, 0);
      expect(rest.regions.single.endMs, 8000);
      expect(first.grid?.offsetMs, grid.offsetMs);
      expect(rest.grid?.offsetMs, cropGrid(grid, 12000).offsetMs);
      expect(audioDurationMs(storage.uploads.first.bytes), 8000);
      expect(audioDurationMs(storage.uploads.last.bytes), 12000);
      expect(pending.queued, [_url]);
      expect(pending.flushed, [_url]);
      expect(audio.players.values.single.clip, isNull);
      expect(audio.players.values.single.loopMode, LoopModeMessage.off);
      expect(audio.players.values.single.playCalls, 0);
    },
  );

  testWidgets('split near an edge explains why and keeps the original', (
    tester,
  ) async {
    await pump(tester, _entry(peaks: _peaks));
    await openMore(tester, 'Split at playhead');
    expect(
      find.text('Move the playhead into the take to split it'),
      findsOneWidget,
    );
    expect(storage.uploads, isEmpty);
    expect(repo.saved, isEmpty);
  });

  testWidgets(
    'shrink uses skipped edges, shifts notes and grid, keeps inner skips',
    (tester) async {
      const grid = AudioGrid(bpm: 120, offsetMs: 300);
      final entry = _entry(
        peaks: _peaks,
        body: 'Capo 2',
        grid: grid,
        notes: const [
          (ms: 500, text: 'discard'),
          (ms: 3425, text: 'keep'),
          (ms: 19500, text: 'tail'),
        ],
        regions: const [
          AudioRegion(
            id: 'head',
            name: '',
            startMs: 0,
            endMs: 1000,
            skip: true,
          ),
          AudioRegion(id: 'a', name: 'Verse', startMs: 1000, endMs: 10000),
          AudioRegion(
            id: 'inner',
            name: '',
            startMs: 10000,
            endMs: 11000,
            skip: true,
          ),
          AudioRegion(id: 'b', name: 'Chorus', startMs: 11000, endMs: 19000),
          AudioRegion(
            id: 'tail',
            name: '',
            startMs: 19000,
            endMs: 20000,
            skip: true,
          ),
        ],
      );
      await pump(tester, entry, bytes: _buildWav(Uint8List(20 * 16000)));
      final ack = repo.saveAck = Completer<void>();
      addTearDown(() {
        if (!ack.isCompleted) ack.complete();
      });
      await openMore(tester, 'Shrink file');
      expect(find.text('Save trim?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Trim'));
      await settleAudio(tester);
      expect(
        pending.queued,
        isEmpty,
        reason: 'never delete before the save is acknowledged',
      );
      expect(storage.suffix, isNotEmpty);
      final saved = repo.saved.single;
      expect(saved.notes, [(ms: 2425, text: 'keep')]);
      expect(saved.body, 'Capo 2');
      expect(saved.peaksRms, isTrue);
      expect(saved.peaks, trimPeaks(_peaks, .05, .95));
      expect(saved.regions.map((r) => r.id), ['a', 'inner', 'b']);
      expect(saved.regions[1].skip, isTrue);
      expect(saved.regions.first.startMs, 0);
      expect(saved.regions.last.endMs, 18000);
      expect(saved.grid?.offsetMs, cropGrid(grid, 1000).offsetMs);
      expect(audioDurationMs(storage.uploads.single.bytes), 18000);
      ack.complete();
      await settleAudio(tester);
      expect(pending.queued, [_url]);
      expect(pending.flushed, [_url]);
      expect(find.text('Trimmed'), findsOneWidget);
    },
  );

  for (final leading in [true, false]) {
    testWidgets(
      'shrink supports only a ${leading ? 'leading' : 'trailing'} skip',
      (tester) async {
        await pump(
          tester,
          _entry(
            peaks: _peaks,
            regions: [
              AudioRegion(
                id: 'a',
                name: 'A',
                startMs: 0,
                endMs: 10000,
                skip: leading,
              ),
              AudioRegion(
                id: 'b',
                name: 'B',
                startMs: 10000,
                endMs: 20000,
                skip: !leading,
              ),
            ],
          ),
          bytes: _buildWav(Uint8List(20 * 16000)),
        );
        await openMore(tester, 'Shrink file');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Trim'));
        await settleAudio(tester);
        expect(audioDurationMs(storage.uploads.single.bytes), 10000);
        expect(repo.saved.single.regions.single.id, leading ? 'b' : 'a');
      },
    );
  }

  testWidgets('shrink is disabled without skipped edges', (tester) async {
    await pump(tester, _entry(peaks: _peaks));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Shrink file'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);
    expect(find.text('Share without skipped edges'), findsNothing);
  });

  for (final action in ['Shrink file', 'Split at playhead']) {
    testWidgets('$action keeps old storage on a failed save', (tester) async {
      await pump(
        tester,
        _entry(
          peaks: _peaks,
          regions: const [
            AudioRegion(
              id: 'skip',
              name: '',
              startMs: 0,
              endMs: 1000,
              skip: true,
            ),
            AudioRegion(id: 'a', name: 'Take', startMs: 1000, endMs: 20000),
          ],
        ),
        bytes: _buildWav(Uint8List(20 * 16000)),
      );
      audio.players.values.single
        ..position = const Duration(seconds: 10)
        ..emit();
      await settleAudio(tester);
      repo.failReplacementSave = true;
      await openMore(tester, action);
      await tester.tap(
        find.widgetWithText(
          ElevatedButton,
          action == 'Shrink file' ? 'Trim' : 'Split',
        ),
      );
      await settleAudio(tester);
      expect(pending.queued, isEmpty);
      expect(pending.flushed, isEmpty);
      expect(audio.players.values.single.loadedUri, _url);
      expect(
        find.textContaining(
          action == 'Shrink file' ? 'Trim failed' : 'Split failed',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('unsupported formats show the same trim error', (tester) async {
    await pump(
      tester,
      _entry(
        peaks: _peaks,
        url: 'https://x/take.m4a',
        regions: const [
          AudioRegion(
            id: 'skip',
            name: '',
            startMs: 0,
            endMs: 1000,
            skip: true,
          ),
          AudioRegion(id: 'a', name: 'Take', startMs: 1000, endMs: 20000),
        ],
      ),
    );
    await openMore(tester, 'Shrink file');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Trim'));
    await settleAudio(tester);
    expect(find.text("This take's format can't be trimmed"), findsOneWidget);
    expect(storage.uploads, isEmpty);
    expect(pending.queued, isEmpty);
  });

  testWidgets('share offers the full file and a copy without skipped edges', (
    tester,
  ) async {
    final bytes = _buildWav(Uint8List(20 * 16000));
    await pump(
      tester,
      _entry(
        peaks: _peaks,
        regions: const [
          AudioRegion(
            id: 'skip',
            name: '',
            startMs: 0,
            endMs: 1000,
            skip: true,
          ),
          AudioRegion(id: 'a', name: 'Take', startMs: 1000, endMs: 19000),
          AudioRegion(
            id: 'tail',
            name: '',
            startMs: 19000,
            endMs: 20000,
            skip: true,
          ),
        ],
      ),
      bytes: bytes,
    );
    await openMore(tester, 'Share');
    expect(share.shared.single.subject, 'Bridge riff');
    expect(share.shared.single.fileNameOverrides, ['Bridge riff.wav']);
    expect(share.shared.single.files!.single.mimeType, 'audio/wav');
    expect(await share.shared.single.files!.single.readAsBytes(), bytes);
    await openMore(tester, 'Share without skipped edges');
    final trimmed = await share.shared.last.files!.single.readAsBytes();
    expect(audioDurationMs(trimmed), 18000);
    expect(trimmed, trimAudio(bytes, startMs: 1000, endMs: 19000));
    expect(repo.saved, isEmpty);
    expect(storage.uploads, isEmpty);
    expect(pending.queued, isEmpty);
  });

  for (final demo in [true, false]) {
    testWidgets(
      '${demo ? 'demo users' : 'band viewers'} can listen and share without edit actions',
      (tester) async {
        await pump(
          tester,
          _entry(peaks: _peaks, notes: const [(ms: 4425, text: 'listen')]),
          demo: demo,
          bandId: demo ? null : 'band',
          bandEditor: false,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Delete recording'), findsNothing);
        expect(find.text('Add note at playhead'), findsNothing);
        expect(find.text('Split at playhead'), findsNothing);
        expect(find.text('Shrink file'), findsNothing);
      },
    );
  }

  testWidgets('delete confirms, queues the object and returns to the list', (
    tester,
  ) async {
    final entry = _entry(peaks: _peaks);
    final router = GoRouter(
      initialLocation: '/take',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Recordings')),
        ),
        GoRoute(
          path: '/take',
          builder: (_, _) => PracticeRegionsScreen(entry: entry),
        ),
      ],
    );
    addTearDown(router.dispose);
    // Push the take so the editor has a route to return to.
    router.go('/');
    await pump(tester, entry, router: router);
    unawaited(router.push<void>('/take'));
    await settleAudio(tester);
    await openMore(tester, 'Delete recording');
    expect(find.text('Delete recording?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    await openMore(tester, 'Delete recording');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await settleAudio(tester);
    expect(repo.deleted, ['e1']);
    expect(pending.queued, [_url]);
    expect(pending.flushed, [_url]);
    expect(find.text('Recordings'), findsOneWidget);
  });
}

/// Mono 16-bit PCM wrapped in a 44-byte RIFF header at 8kHz.
Uint8List _buildWav(Uint8List pcm) {
  final header = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 8000, Endian.little);
  header.setUint32(28, 16000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List(44 + pcm.length)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + pcm.length, pcm);
}
