import 'dart:async';

/// Outcome of awaiting a Firestore write with a server-ack deadline.
enum WriteAck {
  /// The backend acknowledged the write — safe to say "saved".
  confirmed,

  /// No ack within the deadline. With offline persistence (mobile) the write
  /// is queued locally and will sync when connectivity returns; the UI must
  /// say "queued", never "saved".
  queued,
}

/// Awaits [write] but gives up waiting after [deadline].
///
/// Firestore write futures complete only on backend ack (on every platform),
/// so on a flaky network they can hang indefinitely while the write sits in
/// the local queue — and a user who navigates away reads that as "saved".
/// This makes the pending state explicit so call sites can be honest.
///
/// Errors (permission-denied, validation) are NOT swallowed — they still
/// throw, so callers keep their real error handling.
Future<WriteAck> awaitServerAck(
  Future<void> write, {
  Duration deadline = const Duration(seconds: 10),
}) async {
  try {
    await write.timeout(deadline);
    return WriteAck.confirmed;
  } on TimeoutException {
    // ponytail: the write itself keeps running via SDK persistence; we only
    // stop waiting. No retry engine — the SDK's queue is the retry engine.
    unawaited(write.catchError((_) {}));
    return WriteAck.queued;
  }
}
