import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/audio_note_screen.dart';
import 'package:flowgroove/services/audio/audio_file_cache.dart';
import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flowgroove/services/storage_service.dart';
import 'package:flutter/material.dart';
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

  static const duration = Duration(seconds: 20);

  void emit() => _events.add(
    PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: duration,
      duration: duration,
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ),
  );

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    // On a timer, not a microtask: the event stream is a broadcast stream and
    // just_audio subscribes after load() returns, so an immediate emit is
    // dropped and the load never resolves.
    Timer(const Duration(milliseconds: 5), emit);
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

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
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

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

class _EditStorage extends StorageService {
  String? suffix;

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
    return 'https://storage.test/o/new.wav?token=new';
  }
}

class _PendingDeletes extends PendingStorageDeletes {
  _PendingDeletes(this.repo);
  final _InMemoryLabRepo repo;
  final queued = <String>[];
  final flushed = <String>[];

  @override
  Future<void> enqueue(String url) async {
    expect(repo.saved.last.attachmentIds.first, contains('new.wav'));
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
  final saved = <SongLabEntry>[];
  final deleted = <String>[];

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    saved.add(entry);
    await saveAck?.future;
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
  String? url,
  List<AudioMarker> notes = const [],
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
  attachmentIds: [url ?? _url],
  peaks: peaks,
);

List<int> get _peaks => List.generate(200, (i) => i % 256);

void main() {
  final defaultAudioFileCache = audioFileCache;
  setUp(() => audioFileCache = (_, _) async => null);
  tearDown(() => audioFileCache = defaultAudioFileCache);

  late _FakeJustAudio audio;
  late _InMemoryLabRepo repo;
  late List<String> fetched;
  late _EditStorage storage;
  late _PendingDeletes pending;

  setUp(() {
    audio = _FakeJustAudio();
    JustAudioPlatform.instance = audio;
    repo = _InMemoryLabRepo();
    fetched = [];
    storage = _EditStorage();
    pending = _PendingDeletes(repo);
  });

  Future<void> pump(
    WidgetTester tester,
    SongLabEntry entry, {
    Uint8List? bytes,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labRepositoryProvider.overrideWithValue(repo),
          storageServiceProvider.overrideWithValue(storage),
          pendingStorageDeletesProvider.overrideWithValue(pending),
          audioBytesFetcherProvider.overrideWithValue((url) async {
            fetched.add(url);
            return bytes ?? Uint8List(0);
          }),
        ],
        child: MaterialApp(home: AudioNoteScreen(entry: entry)),
      ),
    );
    // setUrl, the first playback event and the backfill are each a separate
    // microtask hop; one pump lands before any of them.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('renders the take title and a transport readout', (tester) async {
    await pump(tester, _entry(peaks: _peaks));
    expect(find.text('Bridge riff'), findsOneWidget);
    expect(find.textContaining(' / '), findsOneWidget);
  });

  testWidgets('play is disabled until a duration is known', (tester) async {
    // Guards the zero-duration state: every trim offset is a fraction of the
    // duration, so acting on it before it's known would seek to nowhere.
    await pump(tester, _entry(peaks: _peaks));
    final play = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.play_circle),
        matching: find.byType(IconButton),
      ),
    );
    expect(play.onPressed, isNull);
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
    // The fake player never reports a position here, so the note lands at 0.
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

  testWidgets('without peaks, offers a slider and explains why not trim', (
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
    await pump(tester, _entry(), bytes: _buildWav(pcm));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(fetched, [_url], reason: 'fetched exactly once');
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.peaks, isNotEmpty);
  });

  testWidgets('does not backfill a take that already has peaks', (
    tester,
  ) async {
    await pump(tester, _entry(peaks: _peaks), bytes: Uint8List(0));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(fetched, isEmpty);
    expect(repo.saved, isEmpty);
  });

  testWidgets('a marker row is tappable', (tester) async {
    // Where it seeks to is covered by shiftMarkers/parseMarkers unit tests and
    // by the on-device pass; this asserts the row is wired up at all.
    await pump(tester, _entry(peaks: _peaks, body: '00:05 chorus entry'));
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('chorus entry'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNotNull);
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
