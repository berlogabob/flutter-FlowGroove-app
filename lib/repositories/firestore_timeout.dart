import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/api_error.dart';

/// The backstop deadline for a client Firestore write.
///
/// Deliberately LONGER than the UI's [awaitServerAck] deadline (10s): a write
/// that has not been acknowledged by then is queued by the SDK's offline
/// persistence, not lost, and the UI is meant to say "queued". If this fired at
/// the same 10s it would race that and turn a queued offline save into a
/// reported failure, so it only catches calls with no ack handling at all.
const firestoreTimeout = Duration(seconds: 30);

/// Runs [op] under [firestoreTimeout] and turns a timeout into the one network
/// error the UI knows how to show.
///
/// ponytail: a helper rather than the same eight-line `on TimeoutException`
/// clause copied onto every method — that copy is exactly what got forgotten on
/// the repository twins while the service half had it, and a call with no
/// deadline hangs the save button forever on a flaky connection.
///
/// [label] appears only in the debug log, so it can be as specific as useful.
Future<T> withFirestoreTimeout<T>(
  String label,
  Future<T> Function() op,
) async {
  try {
    return await op().timeout(firestoreTimeout);
  } on TimeoutException catch (e, stackTrace) {
    debugPrint(
      '⏱️ TIMEOUT: $label timed out after ${firestoreTimeout.inSeconds}s',
    );
    throw ApiError.network(
      message: 'Request timed out. Please check your connection and try again.',
      exception: e,
      stackTrace: stackTrace,
    );
  }
}
