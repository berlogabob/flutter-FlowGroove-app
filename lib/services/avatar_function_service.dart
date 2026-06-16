import 'package:cloud_functions/cloud_functions.dart';

import '../models/api_error.dart';

/// Callable Cloud Function wrapper for avatar operations.
///
/// Mirrors the user's Telegram profile photo into our own Storage bucket
/// server-side (the bot token never leaves the server) and returns the new
/// `photoURL`.
class AvatarFunctionService {
  AvatarFunctionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Imports the signed-in user's Telegram profile photo and returns the new
  /// `photoURL`. Throws [ApiError] on failure (e.g. Telegram not linked, or
  /// no photo available).
  Future<String> importTelegramAvatar() async {
    try {
      final callable = _functions.httpsCallable('importTelegramAvatar');
      final result = await callable.call<Map<String, dynamic>>();
      final url = result.data['photoURL'] as String?;
      if (url == null) {
        throw ApiError.unknown(message: 'No photo URL was returned.');
      }
      return url;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      if (e.code == 'failed-precondition') {
        throw ApiError.validation(
          message: 'Link your Telegram account first.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      if (e.code == 'not-found') {
        throw ApiError.validation(
          message: 'No Telegram profile photo was found.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }
}
