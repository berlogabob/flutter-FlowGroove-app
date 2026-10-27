import 'dart:async';

import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flowgroove/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences({required this.throwOnWrite}) : super.empty();

  final bool throwOnWrite;
  bool fail = false;

  @override
  Future<Map<String, Object>> getAll() async {
    if (fail) throw StateError('Preference read failed');
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail) {
      if (throwOnWrite) throw StateError('Preference write failed');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

/// Records what it was asked to delete; [failing] simulates being offline.
class _FakeStorage extends StorageService {
  _FakeStorage({this.failing = false});

  final bool failing;
  final deleted = <String>[];

  @override
  Future<bool> deleteByUrl(String url) async {
    deleted.add(url);
    return !failing;
  }
}

const _a = 'https://example.test/a.aac?token=1';
const _b = 'https://example.test/b.aac?token=2';

Future<List<String>> _queued() async =>
    (await SharedPreferences.getInstance()).getStringList(
      'pending_storage_deletes',
    ) ??
    const [];

class _PausedStorage extends StorageService {
  final started = Completer<String>();
  final release = Completer<void>();
  final deleted = <String>[];

  @override
  Future<bool> deleteByUrl(String url) async {
    deleted.add(url);
    if (!started.isCompleted) {
      started.complete(url);
      await release.future;
    }
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enqueue records a url once', () async {
    final pending = PendingStorageDeletes(storage: _FakeStorage());
    await pending.enqueue(_a);
    await pending.enqueue(_a);
    expect(await _queued(), [_a]);
  });

  test('cancel drops it without deleting — the undo won', () async {
    final storage = _FakeStorage();
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    await pending.cancel(_a);
    expect(await _queued(), isEmpty);
    expect(storage.deleted, isEmpty, reason: 'the audio must survive an undo');
  });

  for (final throwOnWrite in [false, true]) {
    test(
      'failed cancel rejects and retry survives reload ($throwOnWrite)',
      () async {
        final original = SharedPreferencesStorePlatform.instance;
        addTearDown(() => SharedPreferencesStorePlatform.instance = original);
        final platform = _FailingPreferences(throwOnWrite: throwOnWrite);
        SharedPreferencesStorePlatform.instance = platform;
        final prefs = await SharedPreferences.getInstance();
        final storage = _FakeStorage();
        final pending = PendingStorageDeletes(prefs: prefs, storage: storage);
        await pending.enqueue(_a);
        platform.fail = true;
        await expectLater(pending.cancel(_a), throwsStateError);
        expect(storage.deleted, isEmpty);
        expect(prefs.getStringList('pending_storage_deletes'), [_a]);
        platform.fail = false;
        await prefs.reload();
        expect(prefs.getStringList('pending_storage_deletes'), [_a]);
        final persisted = await platform.getAll();
        SharedPreferences.setMockInitialValues(persisted);
        final restartedPrefs = await SharedPreferences.getInstance();
        expect(restartedPrefs.getStringList('pending_storage_deletes'), [_a]);
        final restarted = PendingStorageDeletes(
          prefs: restartedPrefs,
          storage: storage,
        );
        await restarted.cancel(_a);
        await restartedPrefs.reload();
        expect(
          restartedPrefs.getStringList('pending_storage_deletes'),
          isEmpty,
        );

        await pending.cancel(_a);
        await prefs.reload();
        expect(prefs.getStringList('pending_storage_deletes'), isEmpty);
        await PendingStorageDeletes(prefs: prefs, storage: storage).sweep();
        expect(storage.deleted, isEmpty);
      },
    );
  }

  test('flush deletes and clears the entry', () async {
    final storage = _FakeStorage();
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    await pending.flush(_a);
    expect(storage.deleted, [_a]);
    expect(await _queued(), isEmpty);
  });

  test(
    'flush after a cancel deletes nothing — the undo wins the race',
    () async {
      final storage = _FakeStorage();
      final pending = PendingStorageDeletes(storage: storage);
      await pending.enqueue(_a);
      await pending.cancel(_a); // user hit Undo…
      await pending.flush(_a); // …before the grace period elapsed
      expect(storage.deleted, isEmpty);
    },
  );

  test('flushAfter waits out the grace period, then deletes', () async {
    final storage = _FakeStorage();
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    final done = pending.flushAfter(_a, const Duration(milliseconds: 50));
    expect(storage.deleted, isEmpty, reason: 'not yet — undo is still open');
    await done;
    expect(storage.deleted, [_a]);
  });

  test('a failed flush leaves the url queued for the next launch', () async {
    final storage = _FakeStorage(failing: true);
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    await pending.flush(_a);
    expect(storage.deleted, [_a], reason: 'it tried');
    expect(await _queued(), [_a], reason: 'and will try again');
  });

  test('sweep clears everything it manages to delete', () async {
    final storage = _FakeStorage();
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    await pending.enqueue(_b);
    await pending.sweep();
    expect(storage.deleted, [_a, _b]);
    expect(await _queued(), isEmpty);
  });

  test('sweep keeps what it could not delete', () async {
    final pending = PendingStorageDeletes(storage: _FakeStorage(failing: true));
    await pending.enqueue(_a);
    await pending.sweep();
    expect(await _queued(), [_a]);
  });

  test('sweep on an empty queue touches nothing', () async {
    final storage = _FakeStorage();
    await PendingStorageDeletes(storage: storage).sweep();
    expect(storage.deleted, isEmpty);
  });

  test('sweep observes cancellation while deletion is paused', () async {
    final storage = _PausedStorage();
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    await pending.enqueue(_b);
    final sweeping = pending.sweep();
    expect(await storage.started.future, _a);
    await pending.cancel(_b);
    storage.release.complete();
    await sweeping;
    expect(storage.deleted, [_a]);
    expect(await _queued(), isEmpty);
  });

  test('sweep preserves concurrent enqueue while deletion is paused', () async {
    final storage = _PausedStorage();
    final pending = PendingStorageDeletes(storage: storage);
    const c = 'https://example.test/c.aac?token=3';
    await pending.enqueue(_a);
    final sweeping = pending.sweep();
    await storage.started.future;
    await pending.enqueue(c);
    storage.release.complete();
    await sweeping;
    expect(await _queued(), [c]);
  });
}
