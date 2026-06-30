import 'package:cloud_functions/cloud_functions.dart';

/// Callable wrapper for server-authoritative account deletion.
///
/// Deletion runs entirely in the `deleteAccount` Cloud Function (Admin SDK), so
/// the client does not need to re-authenticate — the server delete bypasses the
/// `requires-recent-login` rule that client-side `User.delete()` enforces.
class AccountFunctionService {
  AccountFunctionService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Deletes the signed-in user's account and all their data, server-side.
  ///
  /// Throws [FirebaseFunctionsException] on failure (e.g. `failed-precondition`
  /// for demo accounts, `unauthenticated` if the session expired).
  Future<void> deleteAccount() async {
    final callable = _functions.httpsCallable('deleteAccount');
    await callable.call<Map<String, dynamic>>();
  }
}
