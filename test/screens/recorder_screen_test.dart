import 'dart:async';

import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/user.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/recorder_screen.dart';
import 'package:flowgroove/services/idea_recorder.dart';
import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.mocks.dart';

class _InMemoryLabRepo extends FirestoreLabRepository {
  _InMemoryLabRepo()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  // Entries keyed by songId — the inbox and linked songs are separate lists,
  // matching the Firestore subcollection layout.
  final entries = <String, List<SongLabEntry>>{};
  bool failDelete = false;
  bool failSave = false;
  int deleteAttempts = 0;
  final _controllers = <String, StreamController<List<SongLabEntry>>>{};

  StreamController<List<SongLabEntry>> _controller(String songId) =>
      _controllers.putIfAbsent(
        songId,
        () => StreamController<List<SongLabEntry>>.broadcast(),
      );

  void _emit(String songId) =>
      _controller(songId).add(List.of(entries[songId] ?? const []));

  @override
  Stream<List<SongLabEntry>> watchEntries(String songId, {String? bandId}) {
    scheduleMicrotask(() => _emit(songId));
    return _controller(songId).stream;
  }

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    if (failSave) throw StateError('secret restore failure');
    final list = entries.putIfAbsent(entry.songId, () => []);
    list.removeWhere((e) => e.id == entry.id);
    list.insert(0, entry);
    _emit(entry.songId);
  }

  @override
  Future<void> deleteEntry(
    String songId,
    String entryId, {
    String? bandId,
  }) async {
    deleteAttempts++;
    if (failDelete) throw StateError('secret delete failure');
    entries[songId]?.removeWhere((e) => e.id == entryId);
    _emit(songId);
  }
}

class _PausedPendingDeletes extends PendingStorageDeletes {
  final release = Completer<void>();
  final enqueued = <String>[];
  final flushed = <String>[];
  final cancelled = <String>[];
  final gracePeriods = <Duration>[];
  Completer<void>? cancelRelease;
  bool failCancel = false;

  @override
  Future<void> enqueue(String url) async {
    enqueued.add(url);
    await release.future;
  }

  @override
  Future<void> cancel(String url) async {
    cancelled.add(url);
    await cancelRelease?.future;
    if (failCancel) throw StateError('secret cancellation failure');
  }

  @override
  Future<void> flushAfter(String url, Duration grace) async {
    flushed.add(url);
    gracePeriods.add(grace);
  }
}

void main() {
  final song = Song(
    id: 's1',
    title: 'Hey Joe',
    artist: 'Jimi Hendrix',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  SongLabEntry recording() => SongLabEntry(
    id: 'rec1',
    songId: ideaInboxSongId,
    type: LabEntryType.recording,
    title: 'Riff in E',
    body: 'hummed on the bus',
    attachmentIds: ['https://example.test/audio.aac?token=private'],
    authorId: 'u1',
    createdAt: DateTime(2026, 7, 16),
    updatedAt: DateTime(2026, 7, 16),
  );

  Future<_InMemoryLabRepo> pump(
    WidgetTester tester, {
    List<SongLabEntry> inbox = const [],
    _Identity? identity,
    _PausedPendingDeletes? pending,
    bool autoStart = false,
  }) async {
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(user.uid).thenReturn('u1');
    when(auth.currentUser).thenReturn(user);
    final repo = _InMemoryLabRepo();
    for (final e in inbox) {
      repo.entries.putIfAbsent(e.songId, () => []).add(e);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWith((ref) => auth),
          appUserProvider.overrideWith(() => identity ?? _Identity()),
          labRepositoryProvider.overrideWithValue(repo),
          pendingStorageDeletesProvider.overrideWithValue(
            pending ?? (_PausedPendingDeletes()..release.complete()),
          ),
          songsProvider.overrideWith((ref) => Stream.value([song])),
        ],
        child: MaterialApp(home: RecorderScreen(autoStart: autoStart)),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repo;
  }

  group('RecorderScreen (#145)', () {
    final authorized = AsyncValue<AppUser?>.data(
      AppUser(uid: 'u1', createdAt: DateTime(2026)),
    );
    final denied = <String, AsyncValue<AppUser?>>{
      'signed out': const AsyncValue.data(null),
      'loading': const AsyncValue.loading(),
      'error': AsyncValue.error(StateError('offline'), StackTrace.current),
      // Construct the cached refresh state Riverpod supplies in production.
      // ignore: invalid_use_of_internal_member
      'cached loading': const AsyncValue<AppUser?>.loading().copyWithPrevious(
        authorized,
      ),
      'cached error': AsyncValue<AppUser?>.error(
        StateError('offline'),
        StackTrace.current,
        // ignore: invalid_use_of_internal_member
      ).copyWithPrevious(authorized),
      'different identity': AsyncValue.data(
        AppUser(uid: 'other', createdAt: DateTime(2026)),
      ),
    };
    for (final entry in denied.entries) {
      testWidgets(
        '${entry.key} blocks autoStart and mutation controls while preserving reading',
        (tester) async {
          await pump(
            tester,
            inbox: [recording()],
            identity: _Identity(entry.value),
            autoStart: true,
          );
          await tester.pumpAndSettle();
          expect(find.text('Riff in E'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Record'),
                )
                .onPressed,
            isNull,
          );
          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'stale Record and open menu cannot mutate after identity change',
      (tester) async {
        final identity = _Identity();
        final repo = await pump(
          tester,
          inbox: [recording()],
          identity: identity,
        );
        final record = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Record'))
            .onPressed!;
        final menu = tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .onSelected!;
        identity.change(denied['different identity']!);
        record();
        menu('delete');
        await tester.pumpAndSettle();
        expect(repo.entries[ideaInboxSongId], hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('revoked selection cannot link a recording', (tester) async {
      final identity = _Identity();
      final repo = await pump(tester, inbox: [recording()], identity: identity);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link to song…'));
      await tester.pumpAndSettle();
      identity.change(denied['different identity']!);
      await tester.tap(find.text('Hey Joe'));
      await tester.pumpAndSettle();
      expect(repo.entries[ideaInboxSongId], hasLength(1));
      expect(repo.entries['s1'], isNull);
    });
    testWidgets('demo can read recordings but cannot record or mutate', (
      tester,
    ) async {
      await pump(
        tester,
        inbox: [recording()],
        identity: _Identity(
          AsyncValue.data(
            AppUser(uid: 'u1', accessRole: 'demo', createdAt: DateTime(2026)),
          ),
        ),
      );
      expect(find.text('Riff in E'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Record'))
            .onPressed,
        isNull,
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });
    testWidgets('record button on top, quiet empty state', (tester) async {
      await pump(tester);

      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Recordings'), findsOneWidget);
      expect(find.textContaining('Hit Record'), findsOneWidget);
    });

    testWidgets('lists inbox recordings as cards', (tester) async {
      await pump(tester, inbox: [recording()]);

      expect(find.text('Riff in E'), findsOneWidget);
      expect(find.textContaining('hummed on the bus'), findsOneWidget);
    });

    testWidgets('link to song moves the recording out of the inbox', (
      tester,
    ) async {
      final repo = await pump(tester, inbox: [recording()]);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link to song…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hey Joe'));
      await tester.pumpAndSettle();

      expect(repo.entries[ideaInboxSongId], isEmpty);
      expect(repo.entries['s1'], hasLength(1));
      expect(repo.entries['s1']!.single.id, 'rec1');
      expect(repo.entries['s1']!.single.title, 'Riff in E');
      expect(find.textContaining('Linked'), findsOneWidget);
    });

    testWidgets('Undo cannot restore a recording after identity change', (
      tester,
    ) async {
      final identity = _Identity();
      final repo = await pump(tester, inbox: [recording()], identity: identity);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.entries[ideaInboxSongId], isEmpty);
      identity.change(denied['different identity']!);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.entries[ideaInboxSongId], isEmpty);
    });
    testWidgets('enqueue completion after identity revocation cancels URL', (
      tester,
    ) async {
      final identity = _Identity();
      final pending = _PausedPendingDeletes();
      final repo = await pump(
        tester,
        inbox: [recording()],
        identity: identity,
        pending: pending,
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(pending.enqueued, recording().attachmentIds);
      identity.change(denied['different identity']!);
      pending.release.complete();
      await tester.pumpAndSettle();
      expect(repo.deleteAttempts, 0);
      expect(repo.entries[ideaInboxSongId], hasLength(1));
      expect(pending.cancelled, recording().attachmentIds);
      expect(pending.flushed, isEmpty);
      expect(find.text('Recording deleted'), findsNothing);
    });
    testWidgets('enqueue completion after unmount cancels URL', (tester) async {
      final pending = _PausedPendingDeletes();
      final repo = await pump(tester, inbox: [recording()], pending: pending);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(pending.enqueued, recording().attachmentIds);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.release.complete();
      await tester.pumpAndSettle();
      expect(repo.deleteAttempts, 0);
      expect(repo.entries[ideaInboxSongId], hasLength(1));
      expect(pending.cancelled, recording().attachmentIds);
      expect(pending.flushed, isEmpty);
    });
    testWidgets('document deletion failure cancels URL and stays private', (
      tester,
    ) async {
      final pending = _PausedPendingDeletes()..release.complete();
      final repo = await pump(tester, inbox: [recording()], pending: pending);
      repo.failDelete = true;
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.entries[ideaInboxSongId], hasLength(1));
      expect(pending.cancelled, recording().attachmentIds);
      expect(pending.flushed, isEmpty);
      expect(find.text('Recording deleted'), findsNothing);
      expect(find.text('Could not delete recording'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Undo waits for cancellation before restoring recording', (
      tester,
    ) async {
      final pending = _PausedPendingDeletes()
        ..release.complete()
        ..cancelRelease = Completer<void>();
      final repo = await pump(tester, inbox: [recording()], pending: pending);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(pending.cancelled, recording().attachmentIds);
      expect(repo.entries[ideaInboxSongId], isEmpty);
      pending.cancelRelease!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Riff in E'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    for (final loss in ['identity', 'unmount']) {
      testWidgets('Undo cancellation completing after $loss cannot restore', (
        tester,
      ) async {
        final pending = _PausedPendingDeletes()
          ..release.complete()
          ..cancelRelease = Completer<void>();
        final identity = _Identity();
        final repo = await pump(
          tester,
          inbox: [recording()],
          pending: pending,
          identity: identity,
        );
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        if (loss == 'identity') {
          identity.change(denied['different identity']!);
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        pending.cancelRelease!.complete();
        await tester.pumpAndSettle();
        expect(repo.entries[ideaInboxSongId], isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
    for (final failure in ['cancellation', 'restore']) {
      testWidgets('Undo $failure failure stays private and offers retry', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = _PausedPendingDeletes()..release.complete();
        final repo = await pump(tester, inbox: [recording()], pending: pending);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        pending.failCancel = failure == 'cancellation';
        repo.failSave = failure == 'restore';
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(repo.entries[ideaInboxSongId], isEmpty);
        expect(find.text("Couldn't restore — try again"), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);
        expect(tester.takeException(), isNull);
        pending.failCancel = false;
        repo.failSave = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Riff in E'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('delete removes the recording with an Undo', (tester) async {
      final pending = _PausedPendingDeletes()..release.complete();
      final repo = await pump(tester, inbox: [recording()], pending: pending);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.entries[ideaInboxSongId], isEmpty);

      expect(pending.flushed, recording().attachmentIds);
      expect(pending.gracePeriods, [const Duration(seconds: 8)]);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.entries[ideaInboxSongId], hasLength(1));
      expect(pending.cancelled, recording().attachmentIds);
    });
  });
}

class _Identity extends AppUserNotifier {
  _Identity([this.initial]);
  final AsyncValue<AppUser?>? initial;
  void change(AsyncValue<AppUser?> value) => state = value;
  @override
  AsyncValue<AppUser?> build() =>
      initial ?? AsyncValue.data(AppUser(uid: 'u1', createdAt: DateTime(2026)));
}
