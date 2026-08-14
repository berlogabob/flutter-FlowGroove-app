/// Role-based permission helpers for FlowGroove.
///
/// Two-level permission system:
/// 1. **App-level** — `AppUser.accessRole` controls what user can do in the app
/// 2. **Band-level** — `BandMember.role` controls what user can do in a band
///
/// Usage in widgets:
/// ```dart
/// final canEdit = ref.watch(canEditProvider);
/// if (!canEdit) return const SizedBox.shrink();
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/band.dart';
import '../models/user.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/data/data_providers.dart';

// ============================================================
// ACCESS ROLE HIERARCHY (App-level permissions)
// ============================================================

/// App-level access roles, ordered from highest to lowest privilege.
class AccessLevel {
  AccessLevel._();

  static const owner = 'owner';
  static const admin = 'admin';
  static const member = 'member';
  static const demo = 'demo';

  /// Check if role A has at least the privileges of role B.
  static bool hasAccess(String role, String minimum) {
    final hierarchy = [owner, admin, member, demo];
    final roleIndex = hierarchy.indexOf(role);
    final minIndex = hierarchy.indexOf(minimum);
    if (roleIndex == -1) return false;
    if (minIndex == -1) return true;
    return roleIndex <= minIndex;
  }
}

// ============================================================
// APP-LEVEL PERMISSION PROVIDERS
// ============================================================

/// Can the current user create/edit/delete content (songs, bands, setlists)?
///
/// Returns `false` for demo accounts.
final canEditProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(appUserProvider);
  return userAsync.when(
    data: (user) => user != null && _canEdit(user),
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Can the current user delete content?
///
/// Same as [canEditProvider] for now, but may diverge if we add
/// a "can edit but not delete" role in the future.
final canDeleteProvider = Provider<bool>((ref) {
  return ref.watch(canEditProvider);
});

/// Can the current user manage band members (add/remove, change roles)?
///
/// Requires at least `admin` app-level access AND admin role in the band.
final canManageMembersProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(appUserProvider);
  return userAsync.when(
    data: (user) => user != null && _canManageMembers(user),
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Can the current user manage app settings (Firebase config, etc.)?
///
/// Only `owner` role.
final canManageAppProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(appUserProvider);
  return userAsync.when(
    data: (user) =>
        user != null &&
        AccessLevel.hasAccess(user.accessRole, AccessLevel.owner),
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Is the current user in demo mode?
final isDemoUserProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(appUserProvider);
  return userAsync.when(
    data: (user) => user != null && user.accessRole == AccessLevel.demo,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Is the current user an admin or owner?
final isAdminUserProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(appUserProvider);
  return userAsync.when(
    data: (user) =>
        user != null &&
        AccessLevel.hasAccess(user.accessRole, AccessLevel.admin),
    loading: () => false,
    error: (_, _) => false,
  );
});

// ============================================================
// BAND-LEVEL PERMISSION HELPERS
// ============================================================

/// Can the current user edit this band's content (songs, setlists, ...)?
///
/// Checks both app-level access (non-demo) AND band-level role via the
/// derived `adminUids`/`editorUids` arrays — the same fields Firestore
/// rules enforce. Never gate on `members[].role` in screens: legacy docs
/// can drift, and the arrays are the server truth.
final canEditBandProvider = Provider.autoDispose.family<bool, String>((
  ref,
  bandId,
) {
  final userAsync = ref.watch(appUserProvider);
  final bandAsync = ref.watch(bandsProvider);

  return userAsync.when(
    data: (user) {
      if (user == null || !_canEdit(user)) return false;
      return bandAsync.when(
        data: (bands) => _canEditBandIn(user.uid, bandId, bands),
        loading: () => false,
        error: (_, _) => false,
      );
    },
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Is the current user an admin of this band?
///
/// Rules reserve band-doc updates, band-song deletes and avatar changes for
/// admins — gate those affordances here, not on [canEditBandProvider].
final isBandAdminProvider = Provider.autoDispose.family<bool, String>((
  ref,
  bandId,
) {
  final userAsync = ref.watch(appUserProvider);
  final bandAsync = ref.watch(bandsProvider);

  return userAsync.when(
    data: (user) {
      if (user == null || !_canEdit(user)) return false;
      return bandAsync.when(
        data: (bands) => _canManageBandMembersIn(user.uid, bandId, bands),
        loading: () => false,
        error: (_, _) => false,
      );
    },
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Can the current user manage members in this band?
///
/// Governed by the **band-level** admin role: any non-demo user who is an
/// admin of this band can manage its members, regardless of their app-level
/// access role. (App-level admin/owner is no longer required here.)
final canManageBandMembersProvider = Provider.autoDispose.family<bool, String>(
  (ref, bandId) => ref.watch(isBandAdminProvider(bandId)),
);

// ============================================================
// INTERNAL HELPERS
// ============================================================

bool _canEdit(AppUser user) {
  return user.accessRole != AccessLevel.demo;
}

bool _canManageMembers(AppUser user) {
  return AccessLevel.hasAccess(user.accessRole, AccessLevel.admin);
}

bool _canEditBandIn(String uid, String bandId, List<Band> bands) {
  final band = bands.where((b) => b.id == bandId).firstOrNull;
  if (band == null) return false;
  return band.adminUids.contains(uid) || band.editorUids.contains(uid);
}

bool _canManageBandMembersIn(String uid, String bandId, List<Band> bands) {
  final band = bands.where((b) => b.id == bandId).firstOrNull;
  if (band == null) return false;
  return band.adminUids.contains(uid);
}
