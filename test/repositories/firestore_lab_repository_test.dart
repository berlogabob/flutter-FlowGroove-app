import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/mocks.mocks.dart';

// Firestore marks snapshots sealed; this boundary fake supplies only reference.
// ignore: subtype_of_sealed_class
class _QueryEntry extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryEntry(this.reference);
  @override
  final DocumentReference<Map<String, dynamic>> reference;
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata({this.hasPendingWrites = false, this.isFromCache = false});

  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;
}

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences({required this.throwOnWrite}) : super.empty();
  final bool throwOnWrite;
  bool fail = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail) {
      if (throwOnWrite) throw StateError('write failed');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
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
    when(doc.set(any, any)).thenAnswer((_) async {});
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

  test(
    'merged saves write notes and clear them after the last deletion',
    () async {
      final entry = SongLabEntry(
        id: 'entry',
        songId: 'song',
        type: LabEntryType.recording,
        authorId: 'user',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        notes: [(ms: 4425, text: 'chorus')],
      );
      await repository.saveEntry(entry);
      final written = verify(doc.set(captureAny, captureAny)).captured;
      expect((written[0] as Map<String, dynamic>)['notes'], [
        {'ms': 4425, 'text': 'chorus'},
      ]);
      expect((written[1] as SetOptions).merge, isTrue);
      await repository.saveEntry(entry.copyWith(notes: const []));
      final cleared = verify(doc.set(captureAny, captureAny)).captured;
      expect(
        (cleared[0] as Map<String, dynamic>)['notes'],
        FieldValue.delete(),
      );
      expect((cleared[1] as SetOptions).merge, isTrue);
    },
  );

  for (final grid in [null, const AudioGrid(bpm: 120)]) {
    test('recording saves explicitly write the tempo grid: $grid', () async {
      final entry = SongLabEntry(
        id: 'entry',
        songId: 'song',
        type: LabEntryType.recording,
        authorId: 'user',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        grid: grid,
      );
      await repository.saveEntry(entry);
      final data =
          verify(doc.set(captureAny, any)).captured.single
              as Map<String, dynamic>;
      expect(data.containsKey('grid'), isTrue);
      expect(data['grid'], grid?.toJson());
    });
  }

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

  group('storage URL reference check', () {
    late MockQuerySnapshot<Map<String, dynamic>> matches;
    late MockDocumentSnapshot<Map<String, dynamic>> confirmed;

    setUp(() {
      matches = MockQuerySnapshot<Map<String, dynamic>>();
      confirmed = MockDocumentSnapshot<Map<String, dynamic>>();
      when(firestore.collectionGroup('labEntries')).thenReturn(collection);
      when(
        collection.where('attachmentIds', arrayContains: url),
      ).thenReturn(collection);
      when(
        collection.where('midiSong.fileUrl', isEqualTo: url),
      ).thenReturn(collection);
      when(collection.get(any)).thenAnswer((_) async => matches);
      when(matches.metadata).thenReturn(_Metadata());
      when(matches.docs).thenReturn([]);
      when(doc.get(any)).thenAnswer((_) async => confirmed);
      when(confirmed.metadata).thenReturn(_Metadata());
      when(confirmed.exists).thenReturn(true);
    });

    test('server absence permits cleanup', () async {
      expect(await repository.isStorageUrlReferenced(url), isFalse);
      final options = verify(
        collection.get(captureAny),
      ).captured.cast<GetOptions>();
      expect(options, hasLength(2));
      expect(options.every((o) => o.source == Source.server), isTrue);
    });

    for (final owner in ['users/user', 'bands/band']) {
      test('live reference under $owner is rechecked on server', () async {
        when(doc.path).thenReturn('$owner/songs/song/labEntries/entry');
        when(matches.docs).thenReturn([_QueryEntry(doc)]);
        when(confirmed.data()).thenReturn({
          'id': 'entry',
          'songId': 'song',
          'type': 'recording',
          'attachmentIds': [url],
        });
        expect(await repository.isStorageUrlReferenced(url), isTrue);
        final options =
            verify(doc.get(captureAny)).captured.single as GetOptions;
        expect(options.source, Source.server);
      });
    }

    test('entry read failure cannot authorize deletion', () async {
      when(doc.path).thenReturn('users/user/songs/song/labEntries/entry');
      when(matches.docs).thenReturn([_QueryEntry(doc)]);
      when(doc.get(any)).thenAnswer((_) async => throw StateError('offline'));
      await expectLater(
        repository.isStorageUrlReferenced(url),
        throwsStateError,
      );
    });

    test('query failure cannot authorize deletion', () async {
      when(
        collection.get(any),
      ).thenAnswer((_) async => throw StateError('denied'));
      await expectLater(
        repository.isStorageUrlReferenced(url),
        throwsStateError,
      );
    });

    for (final metadata in [
      _Metadata(isFromCache: true),
      _Metadata(hasPendingWrites: true),
    ]) {
      test(
        'unconfirmed query cannot authorize deletion: ${metadata.isFromCache}',
        () async {
          when(matches.metadata).thenReturn(metadata);
          await expectLater(
            repository.isStorageUrlReferenced(url),
            throwsStateError,
          );
        },
      );
    }
  });

  for (final bandId in <String?>[null, 'band']) {
    for (final throwOnWrite in [false, true]) {
      test(
        'recording restore requires durable cancellation: $bandId/$throwOnWrite',
        () async {
          SharedPreferences.setMockInitialValues({});
          final original = SharedPreferencesStorePlatform.instance;
          addTearDown(() => SharedPreferencesStorePlatform.instance = original);
          final platform = _FailingPreferences(throwOnWrite: throwOnWrite);
          SharedPreferencesStorePlatform.instance = platform;
          final prefs = await SharedPreferences.getInstance();
          final queue = PendingStorageDeletes(prefs: prefs);
          await queue.enqueue(url);
          final repo = FirestoreLabRepository(
            firestore: firestore,
            auth: auth,
            pendingStorageDeletes: queue,
          );
          final entry = SongLabEntry(
            id: 'entry',
            songId: 'song',
            type: LabEntryType.recording,
            authorId: 'user',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            attachmentIds: [url],
          );
          platform.fail = true;
          await expectLater(
            repo.saveEntry(entry, bandId: bandId),
            throwsStateError,
          );
          verifyNever(doc.set(any, any));
          platform.fail = false;
          await prefs.reload();
          expect(prefs.getStringList('pending_storage_deletes'), [url]);
          await repo.saveEntry(entry, bandId: bandId);
          await prefs.reload();
          expect(prefs.getStringList('pending_storage_deletes'), isEmpty);
          verify(
            doc.set({
              ...entry.toJson(),
              'grid': null,
              'notes': FieldValue.delete(),
            }, any),
          ).called(1);
        },
      );
    }
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
