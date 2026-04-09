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
import '../models/user.dart';
import '../models/band.dart';
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
    error: (_, __) => false,
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
    error: (_, __) => false,
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
    error: (_, __) => false,
  );
});

/// Is the current user in demo mode?
final isDemoUserProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(appUserProvider);
  return userAsync.when(
    data: (user) =>
        user != null && user.accessRole == AccessLevel.demo,
    loading: () => false,
    error: (_, __) => false,
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
    error: (_, __) => false,
  );
});

// ============================================================
// BAND-LEVEL PERMISSION HELPERS
// ============================================================

/// Can the current user edit this band?
///
/// Checks both app-level access AND band-level role.
Provider<bool> canEditBandProvider(String bandId) =>
    Provider<bool>((ref) {
      final userAsync = ref.watch(appUserProvider);
      final bandAsync = ref.watch(bandsProvider);

      return userAsync.when(
        data: (user) {
          if (user == null || !_canEdit(user)) return false;
          return bandAsync.when(
            data: (bands) => _canEditBandIn(bandId, bands),
            loading: () => false,
            error: (_, __) => false,
          );
        },
        loading: () => false,
        error: (_, __) => false,
      );
    });

/// Can the current user manage members in this band?
Provider<bool> canManageBandMembersProvider(String bandId) =>
    Provider<bool>((ref) {
      final userAsync = ref.watch(appUserProvider);
      final bandAsync = ref.watch(bandsProvider);

      return userAsync.when(
        data: (user) {
          if (user == null || !_canManageMembers(user)) return false;
          return bandAsync.when(
            data: (bands) => _canManageBandMembersIn(bandId, bands),
            loading: () => false,
            error: (_, __) => false,
          );
        },
        loading: () => false,
        error: (_, __) => false,
      );
    });

// ============================================================
// INTERNAL HELPERS
// ============================================================

bool _canEdit(AppUser user) {
  return user.accessRole != AccessLevel.demo;
}

bool _canManageMembers(AppUser user) {
  return AccessLevel.hasAccess(user.accessRole, AccessLevel.admin);
}

bool _canEditBandIn(String bandId, List<Band> bands) {
  final band = bands.where((b) => b.id == bandId).firstOrNull;
  if (band == null) return false;
  return band.adminUids.contains(band.createdBy) ||
      band.editorUids.contains(band.createdBy);
}

bool _canManageBandMembersIn(String bandId, List<Band> bands) {
  final band = bands.where((b) => b.id == bandId).firstOrNull;
  if (band == null) return false;
  return band.adminUids.contains(band.createdBy);
}
