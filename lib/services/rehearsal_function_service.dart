import 'package:cloud_functions/cloud_functions.dart';

/// Callable Cloud Function wrapper for rehearsal-plan actions that need to
/// run server-side (e.g. sending Telegram nudges to non-voters).
class RehearsalFunctionService {
  RehearsalFunctionService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static final _callableOptions = HttpsCallableOptions(
    timeout: const Duration(seconds: 30),
  );

  /// Pings band members who haven't voted on [rehearsalId] yet.
  Future<void> remindVoters({
    required String bandId,
    required String rehearsalId,
  }) async {
    final callable = _functions.httpsCallable(
      'remindRehearsalVoters',
      options: _callableOptions,
    );
    await callable.call<Map<String, dynamic>>({
      'bandId': bandId,
      'rehearsalId': rehearsalId,
    });
  }
}
