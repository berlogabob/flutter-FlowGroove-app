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
    return upload.future;
  }
}

class _Repo extends FirestoreLabRepository {
  _Repo() : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());
  final saved = <SongLabEntry>[];
  final save = Completer<void>();
  int deletes = 0;
  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    saved.add(entry);
    await save.future;
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

void main() {
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
