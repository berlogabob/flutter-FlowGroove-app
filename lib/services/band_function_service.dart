import 'package:cloud_functions/cloud_functions.dart';

import '../models/api_error.dart';

/// Result of a [BandFunctionService.joinBand] call.
class JoinBandResult {
  const JoinBandResult({
    required this.bandId,
    required this.bandName,
    required this.alreadyMember,
  });

  final String bandId;
  final String bandName;

  /// True when the caller was already a member (the join was a no-op).
  final bool alreadyMember;
}

/// Callable Cloud Function wrapper for band membership operations.
///
/// Joining is performed server-side (admin SDK) so membership writes are
/// atomic, idempotent, and keep the derived memberUids/adminUids/editorUids
/// arrays in sync with the `members` array.
class BandFunctionService {
  BandFunctionService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Client-side ceiling for callable invocations. The default is 70s, long
  /// enough to look like a frozen UI; 30s comfortably covers a cold start while
  /// surfacing a real failure quickly. On expiry the SDK throws a
  /// `FirebaseFunctionsException` with code `deadline-exceeded`.
  static final _callableOptions = HttpsCallableOptions(
    timeout: const Duration(seconds: 30),
  );

  /// Joins the band identified by [code] (invite code) or [bandId].
  ///
  /// Idempotent: if the caller is already a member, returns a result with
  /// [JoinBandResult.alreadyMember] set to true instead of throwing.
  Future<JoinBandResult> joinBand({String? code, String? bandId}) async {
    final callable = _functions.httpsCallable('joinBand', options: _callableOptions);
    final result = await callable.call<Map<String, dynamic>>(
      _withoutNullValues({'code': code, 'bandId': bandId}),
    );
    return _parseResult(result.data);
  }

  /// Sets [targetUid]'s permission role (admin/editor/viewer) in [bandId].
  /// Caller must be an admin of the band (enforced server-side).
  Future<void> setMemberRole({
    required String bandId,
    required String targetUid,
    required String role,
  }) {
    return _call('setRole', bandId: bandId, targetUid: targetUid, role: role);
  }

  /// Replaces [targetUid]'s music roles in [bandId].
  Future<void> setMemberMusicRoles({
    required String bandId,
    required String targetUid,
    required List<String> musicRoles,
  }) {
    return _call(
      'setMusicRoles',
      bandId: bandId,
      targetUid: targetUid,
      musicRoles: musicRoles,
    );
  }

  /// Removes [targetUid] from [bandId] (and their personal band reference).
  Future<void> removeMember({
    required String bandId,
    required String targetUid,
  }) {
    return _call('remove', bandId: bandId, targetUid: targetUid);
  }

  Future<void> _call(
    String action, {
    required String bandId,
    required String targetUid,
    String? role,
    List<String>? musicRoles,
  }) async {
    final callable = _functions.httpsCallable('updateBandMember', options: _callableOptions);
    try {
      await callable.call<Map<String, dynamic>>(
        _withoutNullValues({
          'action': action,
          'bandId': bandId,
          'targetUid': targetUid,
          'role': role,
          'musicRoles': musicRoles,
        }),
      );
    } on FirebaseFunctionsException catch (e, st) {
      // Surface the function's own message (e.g. "Cannot remove the last
      // admin") instead of letting a raw exception fall through to the generic
      // "Network error" classification in ApiError.fromException.
      throw _toApiError(e, st);
    }
  }

  ApiError _toApiError(FirebaseFunctionsException e, StackTrace st) {
    final msg = e.message?.isNotEmpty == true ? e.message! : null;
    switch (e.code) {
      case 'deadline-exceeded':
      case 'unavailable':
        return ApiError.network(
          message: 'Request timed out. Please check your connection and try again.',
          exception: e,
          stackTrace: st,
        );
      case 'unauthenticated':
        return ApiError.auth(
          message: 'Your session expired. Please sign in again.',
          exception: e,
          stackTrace: st,
        );
      case 'permission-denied':
        return ApiError.permission(
          message: msg ?? 'You do not have permission to do that.',
          exception: e,
          stackTrace: st,
        );
      default:
        return ApiError.unknown(
          message: msg ?? 'Could not complete the request. Please try again.',
          exception: e,
          stackTrace: st,
        );
    }
  }

  JoinBandResult _parseResult(Map<String, dynamic> data) {
    final bandId = data['bandId'] as String?;
    if (bandId == null || bandId.isEmpty) {
      throw const FormatException('Invalid joinBand response.');
    }
    return JoinBandResult(
      bandId: bandId,
      bandName: (data['bandName'] as String?) ?? '',
      alreadyMember: data['alreadyMember'] == true,
    );
  }
}

Map<String, Object?> _withoutNullValues(Map<String, Object?> values) {
  return Map.fromEntries(values.entries.where((entry) => entry.value != null));
}
