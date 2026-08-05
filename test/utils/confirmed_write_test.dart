import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/utils/confirmed_write.dart';

void main() {
  group('awaitServerAck', () {
    test('returns WriteAck.confirmed when write completes quickly', () async {
      final write = Future<void>.delayed(const Duration(milliseconds: 10));

      final result = await awaitServerAck(write);

      expect(result, WriteAck.confirmed);
    });

    test('returns WriteAck.queued when write does not complete within deadline',
        () async {
      // Create a completer that never completes
      final completer = Completer<void>();
      final write = completer.future;

      // Use a tiny deadline
      final result = await awaitServerAck(
        write,
        deadline: const Duration(milliseconds: 50),
      );

      expect(result, WriteAck.queued);

      // Clean up: complete the completer after the test so the test isolate
      // doesn't leave dangling futures
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    test('propagates errors thrown by write', () async {
      final write = Future<void>.error(StateError('denied'));

      expect(
        () => awaitServerAck(write),
        throwsStateError,
      );
    });

    test('does not produce unhandled error when write completes after deadline',
        () async {
      final completer = Completer<void>();
      final write = completer.future;

      // Await with a tiny deadline
      final result = await awaitServerAck(
        write,
        deadline: const Duration(milliseconds: 50),
      );

      expect(result, WriteAck.queued);

      // Now complete the write after the deadline has passed
      // The helper attaches catchError, so no unhandled error should occur
      await Future<void>.delayed(const Duration(milliseconds: 100));
      completer.complete();

      // Give any error handling a chance to run
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('does not produce unhandled error when write throws after deadline',
        () async {
      final completer = Completer<void>();
      final write = completer.future;

      // Await with a tiny deadline
      final result = await awaitServerAck(
        write,
        deadline: const Duration(milliseconds: 50),
      );

      expect(result, WriteAck.queued);

      // Now complete the write with an error after the deadline has passed
      // The helper attaches catchError, so no unhandled error should occur
      await Future<void>.delayed(const Duration(milliseconds: 100));
      completer.completeError(StateError('late error'));

      // Give any error handling a chance to run
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  });
}
