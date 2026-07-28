import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

/// How long a delete stays reversible. Comfortably longer than the 5s Undo
/// snackbar, so the audio outlives every undo the user can actually reach.
const undoGracePeriod = Duration(seconds: 8);

/// Storage objects whose owning document is gone but whose bytes haven't been
/// removed yet.
///
/// Deleting a recording shows an Undo snackbar, so the audio can't go until
/// that grace period expires — and if the app is backgrounded or killed first,
/// the callback never runs and the object would leak forever. Queueing the URL
/// up front and sweeping at the next launch closes that window.
///
/// ponytail: a device-local queue, so a delete on one device is only swept by
/// that device. Fine while an entry's audio is only ever deleted by the person
/// looking at it; move to a Firestore-backed sweep if that stops being true.
class PendingStorageDeletes {
  PendingStorageDeletes({SharedPreferences? prefs, StorageService? storage})
    : _prefs = prefs,
      _storage = storage ?? StorageService();

  static const _key = 'pending_storage_deletes';

  final SharedPreferences? _prefs;
  final StorageService _storage;

  Future<SharedPreferences> get _p async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// Records that [url]'s object should be deleted once its undo window shuts.
  Future<void> enqueue(String url) async {
    final prefs = await _p;
    final queued = prefs.getStringList(_key) ?? const <String>[];
    if (queued.contains(url)) return;
    await prefs.setStringList(_key, [...queued, url]);
  }

  /// Drops [url] from the queue without deleting anything — the undo won.
  Future<void> cancel(String url) async {
    final prefs = await _p;
    final queued = prefs.getStringList(_key);
    if (queued == null || !queued.contains(url)) return;
    await prefs.setStringList(_key, [
      for (final u in queued)
        if (u != url) u,
    ]);
  }

  /// Deletes [url] now, unless [cancel] already removed it — the queue is what
  /// decides, so an undo always wins the race with a pending flush.
  Future<void> flush(String url) async {
    final prefs = await _p;
    if (!(prefs.getStringList(_key) ?? const []).contains(url)) return;
    if (await _storage.deleteByUrl(url)) await cancel(url);
  }

  /// Deletes [url] once [grace] has passed, i.e. once an undo can no longer
  /// bring the entry back.
  ///
  /// Deliberately a timer rather than a snackbar callback: the widget that
  /// shows the snackbar is often unmounted by the very delete it is reporting,
  /// so its callbacks can't be relied on. If the app dies before the timer
  /// fires, [sweep] picks it up at the next launch.
  Future<void> flushAfter(String url, Duration grace) async {
    await Future<void>.delayed(grace);
    await flush(url);
  }

  /// Retries everything still queued. Called once at startup; failures stay
  /// queued for the next launch rather than being dropped.
  Future<void> sweep() async {
    final prefs = await _p;
    final queued = prefs.getStringList(_key) ?? const <String>[];
    if (queued.isEmpty) return;
    final failed = <String>[];
    for (final url in queued) {
      if (!await _storage.deleteByUrl(url)) failed.add(url);
    }
    await prefs.setStringList(_key, failed);
  }
}
