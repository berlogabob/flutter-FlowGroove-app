import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/mocks.mocks.dart';

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata({this.hasPendingWrites = false, this.isFromCache = false});

  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;
}

class _PendingDeletes extends PendingStorageDeletes {
  final calls = <Object>[];

  @override
  Future<void> enqueue(String url) async => calls.add(url);

  @override
  Future<void> flushAfter(String url, Duration grace) async =>
      calls.add((url, grace));
}

void main() {
  const url = 'https://example.test/song.mid';
  late MockDocumentReference<Map<String, dynamic>> doc;
  late _PendingDeletes pending;
  late FirestoreLabRepository repository;
  late MockFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockCollectionReference<Map<String, dynamic>> collection;

  setUp(() {
    firestore = MockFirebaseFirestore();
    auth = MockFirebaseAuth();
    final user = MockUser();
    when(auth.currentUser).thenReturn(user);
    when(user.uid).thenReturn('user');
    collection = MockCollectionReference<Map<String, dynamic>>();
    doc = MockDocumentReference<Map<String, dynamic>>();
    final snapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    when(firestore.collection('bands')).thenReturn(collection);
    when(firestore.collection('users')).thenReturn(collection);
    for (final id in ['band', 'user', 'song', 'entry', 'missing']) {
      when(collection.doc(id)).thenReturn(doc);
    }
    when(doc.collection('songs')).thenReturn(collection);
    when(doc.collection('labEntries')).thenReturn(collection);
    when(doc.get()).thenAnswer((_) async => snapshot);
    when(snapshot.data()).thenReturn(
      SongLabEntry(
        id: 'entry',
        songId: 'song',
        type: LabEntryType.midi,
        authorId: 'user',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        midiSong: const MidiSongMeta(
          fileUrl: url,
          ppq: 480,
          initialBpm: 120,
          tracks: [],
        ),
      ).toJson(),
    );
    pending = _PendingDeletes();
    repository = FirestoreLabRepository(
      firestore: firestore,
      auth: auth,
      pendingStorageDeletes: pending,
    );
  });

  test('reads the exact entry from server, never cache', () async {
    final snapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    when(doc.get(any)).thenAnswer((_) async => snapshot);
    when(snapshot.metadata).thenReturn(_Metadata());
    when(snapshot.exists).thenReturn(true);
    when(
      snapshot.data(),
    ).thenReturn({'id': 'entry', 'songId': 'song', 'type': 'recording'});

    final entry = await repository.readEntryFromServer(
      'song',
      'entry',
      bandId: 'band',
    );

    expect(entry?.id, 'entry');
    final options = verify(doc.get(captureAny)).captured.single as GetOptions;
    expect(options.source, Source.server);
    expect(pending.calls, isEmpty);
  });

  test('server absence returns null', () async {
    final snapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    when(doc.get(any)).thenAnswer((_) async => snapshot);
    when(snapshot.metadata).thenReturn(_Metadata());
    when(snapshot.exists).thenReturn(false);
    expect(
      await repository.readEntryFromServer('song', 'missing', bandId: 'band'),
      isNull,
    );
    expect(pending.calls, isEmpty);
  });

  test('server failure stays unknown rather than returning absence', () async {
    final error = StateError('offline');
    when(doc.get(any)).thenAnswer((_) async => throw error);
    await expectLater(
      repository.readEntryFromServer('song', 'entry', bandId: 'band'),
      throwsA(same(error)),
    );
    expect(pending.calls, isEmpty);
  });

  for (final bandId in <String?>[null, 'band']) {
    test(
      'server read uses exact ${bandId == null ? 'personal' : 'band'} path',
      () async {
        final snapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(snapshot.metadata).thenReturn(_Metadata());
        when(snapshot.exists).thenReturn(false);
        when(doc.get(any)).thenAnswer((_) async => snapshot);
        await repository.readEntryFromServer('song', 'entry', bandId: bandId);
        verifyInOrder([
          firestore.collection(bandId == null ? 'users' : 'bands'),
          collection.doc(bandId ?? 'user'),
          doc.collection('songs'),
          collection.doc('song'),
          doc.collection('labEntries'),
          collection.doc('entry'),
          doc.get(any),
        ]);
      },
    );
  }

  for (final pendingWrite in [false, true]) {
    test(
      'local ${pendingWrite ? 'pending write' : 'cache'} cannot confirm a save',
      () async {
        final snapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(snapshot.metadata).thenReturn(
          _Metadata(hasPendingWrites: pendingWrite, isFromCache: !pendingWrite),
        );
        when(doc.get(any)).thenAnswer((_) async => snapshot);
        await expectLater(
          repository.readEntryFromServer('song', 'entry', bandId: 'band'),
          throwsStateError,
        );
        expect(pending.calls, isEmpty);
      },
    );
  }

  test('queues MIDI cleanup only after document deletion succeeds', () async {
    final deletion = Completer<void>();
    final started = Completer<void>();
    when(doc.delete()).thenAnswer((_) {
      started.complete();
      return deletion.future;
    });

    final result = repository.deleteEntry('song', 'entry', bandId: 'band');
    await started.future;
    expect(pending.calls, isEmpty);

    deletion.complete();
    await result;
    expect(pending.calls, [url, (url, undoGracePeriod)]);
  });

  test('failed document deletion never queues MIDI cleanup', () async {
    final error = StateError('Delete failed');
    when(doc.delete()).thenAnswer((_) async => throw error);

    await expectLater(
      repository.deleteEntry('song', 'entry', bandId: 'band'),
      throwsA(same(error)),
    );
    expect(pending.calls, isEmpty);
  });
}
