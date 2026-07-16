import 'dart:async';

import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/auth/auth_provider.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/screens/songs/song_lab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mocks.mocks.dart';

class _InMemoryLabRepo extends FirestoreLabRepository {
  _InMemoryLabRepo()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  final entries = <SongLabEntry>[];
  final tasks = <SongTask>[];
  final _controller = StreamController<List<SongLabEntry>>.broadcast();
  final _taskController = StreamController<List<SongTask>>.broadcast();

  void _emit() => _controller.add(List.of(entries));
  void _emitTasks() => _taskController.add(List.of(tasks));

  @override
  Stream<List<SongLabEntry>> watchEntries(String songId, {String? bandId}) {
    scheduleMicrotask(_emit);
    return _controller.stream;
  }

  @override
  Stream<List<SongTask>> watchTasks(String songId, {String? bandId}) {
    scheduleMicrotask(_emitTasks);
    return _taskController.stream;
  }

  @override
  Future<void> saveTask(SongTask task, {String? bandId}) async {
    tasks.removeWhere((t) => t.id == task.id);
    tasks.insert(0, task);
    _emitTasks();
  }

  @override
  Future<void> deleteTask(String songId, String taskId, {String? bandId}) async {
    tasks.removeWhere((t) => t.id == taskId);
    _emitTasks();
  }

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    entries.removeWhere((e) => e.id == entry.id);
    entries.insert(0, entry);
    _emit();
  }

  @override
  Future<void> deleteEntry(
    String songId,
    String entryId, {
    String? bandId,
  }) async {
    entries.removeWhere((e) => e.id == entryId);
    _emit();
  }
}

void main() {
  final song = Song(
    id: 's1',
    title: 'Hey Joe',
    artist: 'Jimi Hendrix',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sections: [Section(id: 'sec1', name: 'Verse', duration: 4)],
  );

  Future<_InMemoryLabRepo> pump(WidgetTester tester, {Song? withSong}) async {
    final repo = _InMemoryLabRepo();
    final auth = MockFirebaseAuth();
    when(auth.currentUser).thenReturn(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labRepositoryProvider.overrideWithValue(repo),
          firebaseAuthProvider.overrideWith((ref) => auth),
        ],
        child: MaterialApp(home: SongLabScreen(song: withSong ?? song)),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repo;
  }

  group('SongLabScreen (#67)', () {
    testWidgets('shows quick-add chips and empty state', (tester) async {
      await pump(tester);

      expect(find.text('+ Note'), findsOneWidget);
      expect(find.text('+ Decision'), findsOneWidget);
      expect(find.text('+ Experiment'), findsOneWidget);
      expect(find.text('+ Problem'), findsOneWidget);
      expect(
        find.text('The story of this song starts here'),
        findsOneWidget,
      );
    });

    testWidgets('composing a note saves an entry and renders it', (
      tester,
    ) async {
      final repo = await pump(tester);

      await tester.tap(find.text('+ Note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'What happened?'),
        'Try the riff an octave up',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.entries, hasLength(1));
      expect(repo.entries.single.type, LabEntryType.note);
      expect(repo.entries.single.body, 'Try the riff an octave up');
      expect(find.text('Try the riff an octave up'), findsOneWidget);
    });

    testWidgets('decision quick-add starts with active status', (
      tester,
    ) async {
      final repo = await pump(tester);

      await tester.tap(find.text('+ Decision'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'What happened?'),
        'Half-time last chorus',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.entries.single.status, 'active');
      expect(repo.entries.single.type, LabEntryType.decision);
    });

    testWidgets('tasks tab: add task via sheet and cycle status (#68)', (
      tester,
    ) async {
      final repo = await pump(tester);

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('No homework yet'), findsOneWidget);

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'What needs to be prepared?'),
        'Learn the solo',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(repo.tasks, hasLength(1));
      expect(repo.tasks.single.title, 'Learn the solo');
      expect(repo.tasks.single.status, SongTaskStatus.todo);
      expect(find.text('Learn the solo'), findsOneWidget);

      // Cycle todo → doing via the status chip.
      await tester.tap(find.text('todo'));
      await tester.pumpAndSettle();
      expect(repo.tasks.single.status, SongTaskStatus.doing);
    });

    testWidgets('migrates song.notes into the first entry', (tester) async {
      final annotated = Song(
        id: 's2',
        title: 'Old Song',
        artist: 'X',
        notes: 'capo on 2',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final repo = await pump(tester, withSong: annotated);
      await tester.pumpAndSettle();

      expect(repo.entries, hasLength(1));
      expect(repo.entries.single.title, 'Imported notes');
      expect(repo.entries.single.body, 'capo on 2');
    });
  });
}
