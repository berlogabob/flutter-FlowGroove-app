import 'dart:async';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/mocks.mocks.dart';

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

  setUp(() {
    final firestore = MockFirebaseFirestore();
    final collection = MockCollectionReference<Map<String, dynamic>>();
    doc = MockDocumentReference<Map<String, dynamic>>();
    final snapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    when(firestore.collection('bands')).thenReturn(collection);
    when(collection.doc(any)).thenReturn(doc);
    when(doc.collection(any)).thenReturn(collection);
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
      auth: MockFirebaseAuth(),
      pendingStorageDeletes: pending,
    );
  });

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
