import 'dart:async';

import 'package:flowgroove/models/band.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/widgets/standard_screen_scaffold.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/models/user.dart';
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
  final versions = <SongVersion>[];
  int currentVersionWrites = 0;
  void Function()? afterVersionSave;

  @override
  Future<void> saveVersion(SongVersion version, {String? bandId}) async {
    versions.add(version);
    afterVersionSave?.call();
  }

  @override
  Future<void> setCurrentVersion(
    String songId,
    String versionId, {
    String? bandId,
  }) async {
    currentVersionWrites++;
  }

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
  Future<void> deleteTask(
    String songId,
    String taskId, {
    String? bandId,
  }) async {
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

  Future<_InMemoryLabRepo> pump(
    WidgetTester tester, {
    Song? withSong,
    String? role,
    bool embedded = false,
    _AuthorizedUserNotifier? identity,
  }) async {
    final repo = _InMemoryLabRepo();
    final auth = MockFirebaseAuth();
    final firebaseUser = MockUser();
    when(firebaseUser.uid).thenReturn('u1');
    when(auth.currentUser).thenReturn(firebaseUser);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labRepositoryProvider.overrideWithValue(repo),
          firebaseAuthProvider.overrideWith((ref) => auth),
          appUserProvider.overrideWith(
            () => identity ?? _AuthorizedUserNotifier(),
          ),
          bandsProvider.overrideWith(
            (ref) => Stream.value([
              Band(
                id: 'b1',
                name: 'Band',
                createdBy: 'owner',
                createdAt: DateTime(2026),
                members: [BandMember(uid: 'u1', role: role ?? 'viewer')],
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SongLabScreen(
              song: withSong ?? song,
              bandId: role == null ? null : 'b1',
              embedded: embedded,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repo;
  }

  group('SongLabScreen (#67)', () {
    for (final role in ['viewer', 'editor', 'admin']) {
      for (final embedded in [false, true]) {
        testWidgets(
          '$role ${embedded ? "embedded" : "standalone"} retains viewing and authorized tasks',
          (tester) async {
            final repo = await pump(tester, role: role, embedded: embedded);
            await repo.saveTask(
              SongTask(
                id: 't1',
                songId: song.id,
                title: 'Learn solo',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            );
            await tester.tap(find.text('Tasks'));
            await tester.pumpAndSettle();
            expect(find.text('Learn solo'), findsOneWidget);
            final chip = tester.widget<ActionChip>(
              find.widgetWithText(ActionChip, 'todo'),
            );
            expect(chip.onPressed != null, role != 'viewer');
            expect(
              find.text('Add task'),
              role == 'viewer' ? findsNothing : findsOneWidget,
            );
            if (role != 'viewer') {
              await tester.tap(find.text('todo'));
              await tester.pumpAndSettle();
              expect(repo.tasks.single.status, SongTaskStatus.doing);
            }
            if (embedded) {
              expect(
                tester
                    .widget<IconButton>(
                      find.byWidgetPredicate(
                        (widget) =>
                            widget is IconButton &&
                            widget.tooltip == 'Export history (Markdown)',
                      ),
                    )
                    .onPressed,
                isNotNull,
              );
              expect(
                tester
                        .widget<IconButton>(
                          find.byWidgetPredicate(
                            (widget) =>
                                widget is IconButton &&
                                widget.tooltip == 'Save version',
                          ),
                        )
                        .onPressed !=
                    null,
                role != 'viewer',
              );
            }
          },
        );
      }
    }
    for (final state in <String, AsyncValue<AppUser?>>{
      'signed out': const AsyncValue.data(null),
      'loading': const AsyncValue.loading(),
      'error': AsyncValue.error(StateError('offline'), StackTrace.empty),
    }.entries) {
      testWidgets('${state.key} cannot migrate or offer mutations', (
        tester,
      ) async {
        final repo = await pump(
          tester,
          withSong: Song(
            id: 'notes',
            title: 'Notes',
            artist: '',
            notes: 'keep',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          identity: _AuthorizedUserNotifier(state.value),
        );
        await tester.pump();
        expect(repo.entries, isEmpty);
        expect(find.text('Add'), findsNothing);
        await tester.tap(find.text('Tasks'));
        await tester.pump();
        expect(find.text('Add task'), findsNothing);
      });
    }
    testWidgets('open compose sheet cannot save after permission is revoked', (
      tester,
    ) async {
      final identity = _AuthorizedUserNotifier();
      final repo = await pump(tester, identity: identity);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'What happened?'),
        'Do not write',
      );
      identity.change(const AsyncValue.data(null));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.entries, isEmpty);
    });

    testWidgets('task Undo cannot restore after permission revocation', (
      tester,
    ) async {
      final identity = _AuthorizedUserNotifier();
      final repo = await pump(tester, identity: identity);
      await repo.saveTask(
        SongTask(
          id: 't1',
          songId: song.id,
          title: 'Learn solo',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Learn solo'));
      await tester.pumpAndSettle();
      expect(repo.tasks, isEmpty);
      identity.change(const AsyncValue.data(null));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.tasks, isEmpty);
    });
    testWidgets(
      'authorized version save preserves current version and changelog',
      (tester) async {
        final repo = await pump(tester, embedded: true);
        await tester.tap(find.byTooltip('Save version'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Name (e.g. v0.3, Live, Acoustic)'),
          'Live',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(repo.versions.single.name, 'Live');
        expect(repo.currentVersionWrites, 1);
        expect(repo.entries.single.type, LabEntryType.versionChange);
        expect(find.text('Version: Live'), findsOneWidget);
      },
    );

    testWidgets(
      'version save stops subsequent writes after permission revocation',
      (tester) async {
        final identity = _AuthorizedUserNotifier();
        final repo = await pump(tester, identity: identity, embedded: true);
        repo.afterVersionSave = () =>
            identity.change(const AsyncValue.data(null));
        await tester.tap(find.byTooltip('Save version'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Name (e.g. v0.3, Live, Acoustic)'),
          'Snapshot',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(repo.versions, hasLength(1));
        expect(repo.currentVersionWrites, 0);
        expect(repo.entries, isEmpty);
      },
    );

    testWidgets(
      'band author viewer may delete own entry but is not offered forbidden Undo',
      (tester) async {
        final repo = await pump(tester, role: 'viewer');
        await repo.saveEntry(
          SongLabEntry(
            id: 'e1',
            songId: song.id,
            type: LabEntryType.note,
            title: 'My note',
            authorId: 'u1',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Edit'), findsNothing);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(repo.entries, isEmpty);
        expect(find.text('Undo'), findsNothing);
      },
    );

    testWidgets('viewer retains standalone export without Save version', (
      tester,
    ) async {
      await pump(tester, role: 'viewer');
      await tester.pumpAndSettle();
      final scaffold = tester.widget<StandardScreenScaffold>(
        find.byType(StandardScreenScaffold),
      );
      expect(
        scaffold.menuItems!.map((item) => item.label),
        contains('Export history (Markdown)'),
      );
      expect(
        scaffold.menuItems!.map((item) => item.label),
        isNot(contains('Save version')),
      );
    });

    testWidgets(
      'stale task action reads current permission before the next frame',
      (tester) async {
        final identity = _AuthorizedUserNotifier();
        final repo = await pump(tester, identity: identity);
        await repo.saveTask(
          SongTask(
            id: 't1',
            songId: song.id,
            title: 'Keep todo',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();
        final action = tester
            .widget<ActionChip>(find.widgetWithText(ActionChip, 'todo'))
            .onPressed!;
        identity.change(
          AsyncValue.data(
            AppUser(uid: 'u1', accessRole: 'demo', createdAt: DateTime(2026)),
          ),
        );
        action();
        await tester.pumpAndSettle();
        expect(repo.tasks.single.status, SongTaskStatus.todo);
      },
    );

    testWidgets('demo cannot migrate notes or mutate entries or tasks', (
      tester,
    ) async {
      final repo = _InMemoryLabRepo();
      final auth = MockFirebaseAuth();
      final firebaseUser = MockUser();
      when(firebaseUser.uid).thenReturn('demo');
      when(auth.currentUser).thenReturn(firebaseUser);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            labRepositoryProvider.overrideWithValue(repo),
            firebaseAuthProvider.overrideWith((ref) => auth),
            appUserProvider.overrideWith(() => _DemoUserNotifier()),
          ],
          child: MaterialApp(
            home: SongLabScreen(
              song: Song(
                id: 'demo-song',
                title: 'Demo',
                artist: '',
                notes: 'must not migrate',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.entries, isEmpty);
      expect(find.text('Add'), findsNothing);
      expect(find.text('Save version'), findsNothing);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Add task'), findsNothing);
      expect(repo.tasks, isEmpty);
    });
    testWidgets('shows Add menu and empty state', (tester) async {
      await pump(tester);

      expect(find.text('Add'), findsOneWidget);
      expect(find.byType(PopupMenuButton<LabEntryType>), findsOneWidget);
      expect(find.text('The story of this song starts here'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<LabEntryType>), findsNWidgets(5));
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Decision'), findsOneWidget);
      expect(find.text('Experiment'), findsOneWidget);
      expect(find.text('Problem'), findsOneWidget);
    });

    testWidgets('composing a note saves an entry and renders it', (
      tester,
    ) async {
      final repo = await pump(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note'));
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

    testWidgets('decision quick-add starts with active status', (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decision'));
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

class _AuthorizedUserNotifier extends AppUserNotifier {
  _AuthorizedUserNotifier([this.initial]);
  final AsyncValue<AppUser?>? initial;
  void change(AsyncValue<AppUser?> value) => state = value;

  @override
  AsyncValue<AppUser?> build() =>
      initial ?? AsyncValue.data(AppUser(uid: 'u1', createdAt: DateTime(2026)));
}

class _DemoUserNotifier extends AppUserNotifier {
  @override
  AsyncValue<AppUser?> build() => AsyncValue.data(
    AppUser(uid: 'demo', accessRole: 'demo', createdAt: DateTime(2026)),
  );
}
