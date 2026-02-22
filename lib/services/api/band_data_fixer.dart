import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/band.dart';

/// Console script to fix band data integrity issues.
///
/// For Flutter app, use: await Firebase.initializeApp();
void main() async {
  if (kDebugMode) {
    print('Starting band data repair...\n');
  }
}

/// Extension to fix band data integrity issues.
///
/// This adds validation and auto-repair for adminUids/editorUids fields.
extension BandDataFix on Band {
  /// Validates and repairs the band's uid arrays.
  /// Returns true if repairs were made.
  bool validateAndRepair() {
    bool wasModified = false;

    // Calculate expected values from members
    final expectedMemberUids = members.map((m) => m.uid).toList();
    final expectedAdminUids = members
        .where((m) => m.role == BandMember.roleAdmin)
        .map((m) => m.uid)
        .toList();
    final expectedEditorUids = members
        .where((m) => m.role == BandMember.roleEditor)
        .map((m) => m.uid)
        .toList();

    // Check and repair memberUids
    if (!_listsEqual(memberUids, expectedMemberUids)) {
      wasModified = true;
    }

    // Check and repair adminUids
    if (!_listsEqual(adminUids, expectedAdminUids)) {
      wasModified = true;
    }

    // Check and repair editorUids
    if (!_listsEqual(editorUids, expectedEditorUids)) {
      wasModified = true;
    }

    return wasModified;
  }

  /// Check if uid arrays are consistent with members.
  bool hasValidUidArrays() {
    final expectedMemberUids = members.map((m) => m.uid).toList();
    final expectedAdminUids = members
        .where((m) => m.role == BandMember.roleAdmin)
        .map((m) => m.uid)
        .toList();
    final expectedEditorUids = members
        .where((m) => m.role == BandMember.roleEditor)
        .map((m) => m.uid)
        .toList();

    return _listsEqual(memberUids, expectedMemberUids) &&
        _listsEqual(adminUids, expectedAdminUids) &&
        _listsEqual(editorUids, expectedEditorUids);
  }

  /// Compare two lists for equality (order-independent).
  bool _listsEqual(List<String>? a, List<String> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    return Set<String>.from(a).containsAll(Set<String>.from(b));
  }
}

/// Service to fix band data in Firestore.
class BandDataFixer {
  final FirebaseFirestore _firestore;

  BandDataFixer({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fix a single band document.
  Future<bool> fixBand(String bandId) async {
    try {
      final bandDoc = await _firestore.collection('bands').doc(bandId).get();

      if (!bandDoc.exists) {
        if (kDebugMode) print('❌ Band $bandId does not exist');
        return false;
      }

      final bandData = bandDoc.data()!;
      final members =
          (bandData['members'] as List<dynamic>?)
              ?.map((m) => BandMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];

      // Calculate correct uid arrays
      final memberUids = members.map((m) => m.uid).toList();
      final adminUids = members
          .where((m) => m.role == BandMember.roleAdmin)
          .map((m) => m.uid)
          .toList();
      final editorUids = members
          .where((m) => m.role == BandMember.roleEditor)
          .map((m) => m.uid)
          .toList();

      // Check if fix is needed
      final existingMemberUids = bandData['memberUids'] as List<dynamic>?;
      final existingAdminUids = bandData['adminUids'] as List<dynamic>?;
      final existingEditorUids = bandData['editorUids'] as List<dynamic>?;

      final needsFix =
          !_listsEqual(existingMemberUids, memberUids) ||
          !_listsEqual(existingAdminUids, adminUids) ||
          !_listsEqual(existingEditorUids, editorUids);

      if (!needsFix) {
        if (kDebugMode) print('✅ Band "$bandId" already has valid uid arrays');
        return false;
      }

      // Apply fix
      await bandDoc.reference.update({
        'memberUids': memberUids,
        'adminUids': adminUids,
        'editorUids': editorUids,
      });

      if (kDebugMode) {
        print(
          '✅ Fixed band "$bandId": ${adminUids.length} admins, ${editorUids.length} editors, ${memberUids.length} members',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error fixing band $bandId: $e');
      return false;
    }
  }

  /// Fix all bands.
  Future<Map<String, int>> fixAllBands() async {
    int total = 0;
    int fixed = 0;
    int errors = 0;

    try {
      final bandsSnapshot = await _firestore.collection('bands').get();
      total = bandsSnapshot.size;

      if (kDebugMode) print('🔍 Checking $total bands...');

      for (final bandDoc in bandsSnapshot.docs) {
        try {
          final wasFixed = await fixBand(bandDoc.id);
          if (wasFixed) fixed++;
        } catch (e) {
          errors++;
          if (kDebugMode) print('❌ Error processing band ${bandDoc.id}: $e');
        }
      }

      if (kDebugMode) {
        print('');
        print('=' * 50);
        print('📊 FIX SUMMARY');
        print('=' * 50);
        print('Total bands: $total');
        print('Fixed: $fixed');
        print('Already valid: ${total - fixed - errors}');
        print('Errors: $errors');
        print('=' * 50);
      }

      return {'total': total, 'fixed': fixed, 'errors': errors};
    } catch (e) {
      if (kDebugMode) print('❌ Fatal error: $e');
      return {'total': total, 'fixed': fixed, 'errors': errors};
    }
  }

  /// Compare two lists for equality.
  bool _listsEqual(List<dynamic>? a, List<dynamic> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    return Set<String>.from(
      a.cast<String>(),
    ).containsAll(Set<String>.from(b.cast<String>()));
  }
}
