import 'dart:convert';
import 'dart:io';

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

  /// Imports the signed-in user's Google account photo server-side (avoids the
  /// browser CORS wall that breaks a client fetch on web) and returns the new
  /// `photoURL`. Throws [ApiError] when no Google photo is available.
  Future<String> importGoogleAvatar() async {
    try {
      final callable = _functions.httpsCallable('importGoogleAvatar');
      final result = await callable.call<Map<String, dynamic>>();
      final url = result.data['photoURL'] as String?;
      if (url == null) {
        throw ApiError.unknown(message: 'No photo URL was returned.');
      }
      return url;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      if (e.code == 'not-found') {
        throw ApiError.validation(
          message: 'No Google profile photo is available to import.',
          exception: e,
          stackTrace: stackTrace,
        );
      }
      throw ApiError.fromException(e, stackTrace: stackTrace);
    }
  }

  /// Sets a band's avatar by sending the (already resized) image to the
  /// server-authoritative `setBandAvatar` callable, which verifies band-admin
  /// status and writes to Storage via the Admin SDK. Returns the new
  /// `photoURL`. Throws [ApiError] (e.g. permission) on failure.
  Future<String> setBandAvatar(File file, String bandId) async {
    try {
      final bytes = await file.readAsBytes();
      final callable = _functions.httpsCallable('setBandAvatar');
      final result = await callable.call<Map<String, dynamic>>({
        'bandId': bandId,
        'imageBase64': base64Encode(bytes),
      });
      final url = result.data['photoURL'] as String?;
      if (url == null) {
        throw ApiError.unknown(message: 'No photo URL was returned.');
      }
      return url;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      throw _mapBandAvatarError(e, stackTrace);
    }
  }

  /// Removes a band's avatar via the server-authoritative `removeBandAvatar`
  /// callable (band-admin only).
  Future<void> removeBandAvatar(String bandId) async {
    try {
      final callable = _functions.httpsCallable('removeBandAvatar');
      await callable.call<Map<String, dynamic>>({'bandId': bandId});
    } on FirebaseFunctionsException catch (e, stackTrace) {
      throw _mapBandAvatarError(e, stackTrace);
    }
  }

  ApiError _mapBandAvatarError(
    FirebaseFunctionsException e,
    StackTrace stackTrace,
  ) {
    if (e.code == 'permission-denied') {
      return ApiError.permission(
        message: 'Only band admins can change the band avatar.',
        exception: e,
        stackTrace: stackTrace,
      );
    }
    return ApiError.fromException(e, stackTrace: stackTrace);
  }
}
