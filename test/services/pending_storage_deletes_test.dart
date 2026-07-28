import 'package:flowgroove/services/pending_storage_deletes.dart';
import 'package:flowgroove/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('flush deletes and clears the entry', () async {
    final storage = _FakeStorage();
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    await pending.flush(_a);
    expect(storage.deleted, [_a]);
    expect(await _queued(), isEmpty);
  });

  test('flush after a cancel deletes nothing — the undo wins the race', () async {
    final storage = _FakeStorage();
    final pending = PendingStorageDeletes(storage: storage);
    await pending.enqueue(_a);
    await pending.cancel(_a); // user hit Undo…
    await pending.flush(_a); // …before the grace period elapsed
    expect(storage.deleted, isEmpty);
  });

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
}
