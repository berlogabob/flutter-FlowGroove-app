import 'dart:async';
import 'dart:typed_data';

import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/songs/components/lab_recording_sheet.dart';
import 'package:flowgroove/services/idea_recorder.dart';
import 'package:flowgroove/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.mocks.dart';

class _Identity extends AppUserNotifier {
  @override
  AsyncValue<AppUser?> build() =>
      AsyncData(AppUser(uid: 'u1', createdAt: DateTime(2026)));
  AsyncValue<AppUser?> get identity => state;
  set identity(AsyncValue<AppUser?> value) => state = value;
}

class _Storage extends StorageService {
  final upload = Completer<String>();
  int calls = 0;
  String? target;
  String? entryId;
  int deletes = 0;

  @override
  Future<bool> deleteByUrl(String url) async {
    deletes++;
    return true;
  }

  @override
  Future<String> uploadLabAudio(
    Uint8List bytes, {
    required String? bandId,
    required String songId,
    required String entryId,
    String ext = 'm4a',
    String contentType = 'audio/mp4',
  }) {
    calls++;
    target = songId;
    this.entryId = entryId;
    return upload.future;
  }
}

class _Repo extends FirestoreLabRepository {
  _Repo() : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());
  final saved = <SongLabEntry>[];
  final save = Completer<void>();
  int deletes = 0;
  int reads = 0;
  Future<SongLabEntry?> Function()? read;
  Future<void> Function()? write;

  @override
  Future<SongLabEntry?> readEntryFromServer(
    String songId,
    String entryId, {
    String? bandId,
  }) async {
    expect(songId, saved.first.songId);
    expect(entryId, saved.first.id);
    expect(bandId, saved.first.bandId);
    reads++;
    return read == null ? null : await read!();
  }

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    saved.add(entry);
    await (write == null ? save.future : write!());
  }

  @override
  Future<void> deleteEntry(
    String songId,
    String entryId, {
    String? bandId,
  }) async {
    deletes++;
  }
}

Future<void> _capture(
  WidgetTester tester,
  _Storage storage,
  _Repo repo, {
  _Identity? identity,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appUserProvider.overrideWith(() => identity ?? _Identity()),
        storageServiceProvider.overrideWithValue(storage),
        labRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => captureIdea(context, ref),
              child: const Text('Capture'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Capture'));
  await tester.pumpAndSettle();
  Navigator.of(
    tester.element(find.byType(LabRecordingSheet)),
  ).pop(LabRecordingResult(bytes: Uint8List.fromList([1]), ext: 'aac'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> expectAudioPreserved(_Storage storage, _Repo repo) async {
    expect(storage.deletes, 0);
    expect(repo.deletes, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pending_storage_deletes') ?? [], isEmpty);
  }

  testWidgets('upload failure has its own safe message and never saves', (
    tester,
  ) async {
    final storage = _Storage();
    final repo = _Repo();
    await _capture(tester, storage, repo);
    storage.upload.completeError(StateError('private upload error'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't upload the recording"), findsOneWidget);
    expect(repo.saved, isEmpty);
    expect(find.textContaining('private'), findsNothing);
  });

  testWidgets('server absence offers retry of the same entry and upload', (
    tester,
  ) async {
    final storage = _Storage();
    final repo = _Repo()
      ..write = (() async => throw StateError('private save error'));
    await _capture(tester, storage, repo);
    storage.upload.complete('https://example.test/audio');
    await tester.pumpAndSettle();
    expect(find.text('Recording uploaded but not saved yet'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    expect(repo.reads, 1);
    final original = repo.saved.single;
    repo.write = () async {};
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.saved, hasLength(2));
    expect(repo.saved.last, same(original));
    expect(original.id, storage.entryId);
    expect(original.attachmentIds, ['https://example.test/audio']);
    expect(storage.calls, 1);
    expect(storage.deletes, 0);
    expect(repo.deletes, 0);
    expect(
      find.text('Saved — link it to a song from the Recorder list'),
      findsOneWidget,
    );
  });

  for (final outcome in ['exception', 'timeout']) {
    testWidgets('$outcome after write is reconciled as saved without retry', (
      tester,
    ) async {
      final storage = _Storage();
      final repo = _Repo();
      if (outcome == 'exception') {
        repo.write = () async => throw StateError('after write');
      }
      repo.read = () async => repo.saved.single;
      await _capture(tester, storage, repo);
      storage.upload.complete('https://example.test/audio');
      await tester.pumpAndSettle();
      if (outcome == 'timeout') {
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();
      }
      expect(repo.reads, 1);
      expect(repo.saved, hasLength(1));
      expect(
        find.text('Saved — link it to a song from the Recorder list'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      await expectAudioPreserved(storage, repo);
      if (outcome == 'timeout') {
        repo.save.complete();
        await tester.pumpAndSettle();
        expect(repo.saved, hasLength(1));
      }
    });
  }

  for (final outcome in ['exception', 'timeout']) {
    testWidgets(
      'server read $outcome keeps outcome unknown and Retry only reconciles',
      (tester) async {
        final storage = _Storage();
        final repo = _Repo()
          ..write = (() async => throw StateError('private write'));
        final read = Completer<SongLabEntry?>();
        repo.read = outcome == 'exception'
            ? () async => throw StateError('private read')
            : () => read.future;
        await _capture(tester, storage, repo);
        storage.upload.complete('https://example.test/audio');
        await tester.pumpAndSettle();
        if (outcome == 'timeout') {
          await tester.pump(const Duration(seconds: 11));
          await tester.pumpAndSettle();
        }
        expect(find.text('Not confirmed — check connection'), findsOneWidget);
        expect(find.textContaining('private'), findsNothing);
        await expectAudioPreserved(storage, repo);
        repo.read = () async => repo.saved.single;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(repo.reads, 2);
        expect(repo.saved, hasLength(1));
        expect(storage.calls, 1);
        expect(
          find.text('Saved — link it to a song from the Recorder list'),
          findsOneWidget,
        );
        await expectAudioPreserved(storage, repo);
        if (outcome == 'timeout') {
          read.completeError(StateError('late read failure'));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets('unknown becomes retryable only after server confirms absence', (
    tester,
  ) async {
    final storage = _Storage();
    final repo = _Repo()
      ..write = (() async => throw StateError('uncertain'))
      ..read = (() async => throw StateError('offline'));
    await _capture(tester, storage, repo);
    storage.upload.complete('https://example.test/audio');
    await tester.pumpAndSettle();
    repo.read = () async => null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.saved, hasLength(1));
    expect(find.text('Recording uploaded but not saved yet'), findsOneWidget);
    repo.write = () async {};
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.saved, hasLength(2));
    expect(repo.saved.last, same(repo.saved.first));
    expect(storage.calls, 1);
    await expectAudioPreserved(storage, repo);
  });

  testWidgets(
    'authority loss during save prevents reconciliation and feedback',
    (tester) async {
      final storage = _Storage();
      final identity = _Identity();
      final repo = _Repo();
      await _capture(tester, storage, repo, identity: identity);
      storage.upload.complete('https://example.test/audio');
      await tester.pumpAndSettle();
      identity.identity = const AsyncData(null);
      repo.save.completeError(StateError('uncertain'));
      await tester.pumpAndSettle();
      expect(repo.reads, 0);
      expect(
        find.text(
          'Recording stopped because access changed. Please try again.',
        ),
        findsOneWidget,
      );
      await expectAudioPreserved(storage, repo);
    },
  );

  testWidgets('offline queued save and unavailable server keep audio unknown', (
    tester,
  ) async {
    final storage = _Storage();
    final repo = _Repo()..read = (() async => throw StateError('offline'));
    await _capture(tester, storage, repo);
    storage.upload.complete('https://example.test/audio');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Not confirmed — check connection'), findsOneWidget);
    await expectAudioPreserved(storage, repo);
    repo.save.completeError(StateError('late save error'));
    await tester.pumpAndSettle();
    expect(repo.saved, hasLength(1));
    await expectAudioPreserved(storage, repo);
  });

  testWidgets('authority loss during server read prevents saved feedback', (
    tester,
  ) async {
    final storage = _Storage();
    final identity = _Identity();
    final repo = _Repo()..write = (() async => throw StateError('uncertain'));
    final read = Completer<SongLabEntry?>();
    repo.read = () => read.future;
    await _capture(tester, storage, repo, identity: identity);
    storage.upload.complete('https://example.test/audio');
    await tester.pumpAndSettle();
    identity.identity = const AsyncData(null);
    read.complete(repo.saved.single);
    await tester.pumpAndSettle();
    expect(
      find.text('Recording stopped because access changed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    await expectAudioPreserved(storage, repo);
  });

  for (final unknown in [false, true]) {
    testWidgets(
      'authority loss prevents ${unknown ? 'reconciliation' : 'save'} Retry',
      (tester) async {
        final storage = _Storage();
        final identity = _Identity();
        final repo = _Repo()
          ..write = (() async => throw StateError('uncertain'));
        if (unknown) repo.read = () async => throw StateError('offline');
        await _capture(tester, storage, repo, identity: identity);
        storage.upload.complete('https://example.test/audio');
        await tester.pumpAndSettle();
        identity.identity = AsyncData(
          AppUser(uid: 'u2', createdAt: DateTime(2026)),
        );
        await tester.pump();
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(repo.saved, hasLength(1));
        expect(repo.reads, 1);
        expect(
          find.text(
            'Recording stopped because access changed. Please try again.',
          ),
          findsOneWidget,
        );
        await expectAudioPreserved(storage, repo);
      },
    );
  }

  testWidgets('account switch while sheet is open prevents upload', (
    tester,
  ) async {
    final identity = _Identity();
    final storage = _Storage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUserProvider.overrideWith(() => identity),
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => captureIdea(context, ref),
                child: const Text('Capture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    identity.identity = AsyncData(
      AppUser(uid: 'u2', createdAt: DateTime(2026)),
    );
    Navigator.of(
      tester.element(find.byType(LabRecordingSheet)),
    ).pop(LabRecordingResult(bytes: Uint8List.fromList([1]), ext: 'aac'));
    await tester.pumpAndSettle();
    expect(storage.calls, 0);
    expect(
      find.text('Recording stopped because access changed. Please try again.'),
      findsOneWidget,
    );
  });
  for (final loss in ['switch', 'demo', 'loading', 'error', 'band']) {
    testWidgets('$loss during upload prevents save', (tester) async {
      final identity = _Identity();
      final storage = _Storage();
      final repo = _Repo();
      var canEdit = true;
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUserProvider.overrideWith(() => identity),
            storageServiceProvider.overrideWithValue(storage),
            labRepositoryProvider.overrideWithValue(repo),
            bandsProvider.overrideWith((ref) => Stream.value([])),
            canEditBandProvider('b1').overrideWith((ref) => canEdit),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(bandsProvider);
                container = ProviderScope.containerOf(context);
                return Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        captureIdea(context, ref, songId: 's1', bandId: 'b1'),
                    child: const Text('Capture'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture'));
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(LabRecordingSheet)),
      ).pop(LabRecordingResult(bytes: Uint8List.fromList([1]), ext: 'aac'));
      await tester.pumpAndSettle();
      expect(storage.calls, 1);
      expect(storage.target, 's1');
      switch (loss) {
        case 'switch':
          identity.identity = AsyncData(
            AppUser(uid: 'u2', createdAt: DateTime(2026)),
          );
        case 'demo':
          identity.identity = AsyncData(
            AppUser(uid: 'u1', accessRole: 'demo', createdAt: DateTime(2026)),
          );
        case 'loading':
          identity.identity = const AsyncLoading();
        case 'error':
          identity.identity = AsyncError(
            StateError('private'),
            StackTrace.current,
          );
        case 'band':
          canEdit = false;
          container.invalidate(canEditBandProvider('b1'));
      }
      storage.upload.complete('https://example.test/audio');
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(repo.deletes, 0);
      expect(
        find.text(
          'Recording stopped because access changed. Please try again.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('authority loss during link save preserves inbox source', (
    tester,
  ) async {
    final identity = _Identity();
    final repo = _Repo();
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUserProvider.overrideWith(() => identity),
          labRepositoryProvider.overrideWithValue(repo),
        ],
        child: Consumer(
          builder: (context, value, _) {
            ref = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final now = DateTime(2026);
    final future = linkIdeaToSong(
      ref,
      SongLabEntry(
        id: 'idea',
        songId: ideaInboxSongId,
        type: LabEntryType.recording,
        authorId: 'u1',
        createdAt: now,
        updatedAt: now,
      ),
      songId: 's1',
    );
    final check = expectLater(future, throwsStateError);
    identity.identity = const AsyncData(null);
    repo.save.complete();
    await check;
    expect(repo.saved.single.songId, 's1');
    expect(repo.saved.single.authorId, 'u1');
    expect(repo.deletes, 0);
  });
}
