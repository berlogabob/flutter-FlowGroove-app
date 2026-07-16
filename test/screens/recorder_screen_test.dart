import 'dart:async';

import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/recorder_screen.dart';
import 'package:flowgroove/services/idea_recorder.dart';
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
    entries[songId]?.removeWhere((e) => e.id == entryId);
    _emit(songId);
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
    authorId: 'u1',
    createdAt: DateTime(2026, 7, 16),
    updatedAt: DateTime(2026, 7, 16),
  );

  Future<_InMemoryLabRepo> pump(
    WidgetTester tester, {
    List<SongLabEntry> inbox = const [],
  }) async {
    final repo = _InMemoryLabRepo();
    for (final e in inbox) {
      repo.entries.putIfAbsent(e.songId, () => []).add(e);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labRepositoryProvider.overrideWithValue(repo),
          songsProvider.overrideWith((ref) => Stream.value([song])),
        ],
        child: const MaterialApp(home: RecorderScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repo;
  }

  group('RecorderScreen (#145)', () {
    testWidgets('record button on top, quiet empty state', (tester) async {
      await pump(tester);

      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Recordings'), findsOneWidget);
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
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

    testWidgets('delete removes the recording with an Undo', (tester) async {
      final repo = await pump(tester, inbox: [recording()]);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.entries[ideaInboxSongId], isEmpty);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.entries[ideaInboxSongId], hasLength(1));
    });
  });
}
