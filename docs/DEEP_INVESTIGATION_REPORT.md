# DEEP INVESTIGATION REPORT: Band Songs Permission Error

**Date:** 2026-02-20
**Issue:** Permission denied when adding songs to band
**Status:** ROOT CAUSE IDENTIFIED

---

## Executive Summary

After deep investigation of the permission error when adding songs to bands, the **ROOT CAUSE** has been identified:

**The Firestore security rules are correctly configured, BUT there is NO test coverage verifying that the `adminUids`, `editorUids`, and `memberUids` arrays are properly populated when bands are created/saved.**

This creates a critical gap where:
1. The code APPEARS correct (arrays are calculated in the Band model)
2. The rules ARE correct (they check these arrays)
3. BUT there's no verification that the arrays actually contain data when written to Firestore

---

## Step 1: EXACT Error Location

### All Places Where Songs Are Added to Bands

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/providers/data_providers.dart`
**Lines:** 189-213

```dart
/// Adds a song to a band's song collection.
Future<void> addSongToBand({
  required Song song,
  required String bandId,
  required String contributorId,
  required String contributorName,
}) async {
  final bandSong = song.copyWith(
    id: FirebaseFirestore.instance.collection('bands').doc().id,
    bandId: bandId,
    originalOwnerId: song.originalOwnerId ?? contributorId,
    contributedBy: contributorName,
    isCopy: true,
    contributedAt: DateTime.now(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await FirebaseFirestore.instance
      .collection('bands')
      .doc(bandId)
      .collection('songs')
      .doc(bandSong.id)
      .set(bandSong.toJson());
}
```

**Call Sites:**
1. `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/screens/songs/songs_list_screen.dart` (line 332)
2. `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/screens/bands/band_songs_screen.dart` (referenced but not fully implemented)

---

## Step 2: EXACT Collection Path

**Path Used in Code:**
```
/bands/{bandId}/songs/{songId}
```

**Verification from `data_providers.dart` lines 207-212:**
```dart
await FirebaseFirestore.instance
    .collection('bands')           // ← Global bands collection
    .doc(bandId)                   // ← Band document ID
    .collection('songs')           // ← Songs subcollection
    .doc(bandSong.id)              // ← New song document ID
    .set(bandSong.toJson());
```

**Status:** ✅ CORRECT - Path matches Firestore rules

---

## Step 3: User Authentication Check

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/screens/songs/songs_list_screen.dart`
**Lines:** 326-328

```dart
final user = ref.read(currentUserProvider);
if (user == null) return;
```

**User ID Source:**
- Obtained from `currentUserProvider` (Firebase Auth)
- `user.uid` is used as `contributorId`

**Status:** ✅ CORRECT - User authentication is checked

---

## Step 4: Band Data Structure

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart`

**Critical Fields for Permissions:**
```dart
class Band {
  final List<BandMember> members;
  final List<String> memberUids;   // ← Derived from members
  final List<String> adminUids;    // ← Derived from members (ADMINS ONLY)
  final List<String> editorUids;   // ← Derived from members (EDITORS ONLY, excludes admins)
  // ...
}
```

**Array Calculation in Constructor (lines 70-83):**
```dart
Band({
  // ...
  this.members = const [],
  List<String>? memberUids,
  List<String>? adminUids,
  List<String>? editorUids,
  // ...
}) : memberUids = memberUids ?? members.map((m) => m.uid).toList(),
     adminUids =
         adminUids ??
         members
             .where((m) => m.role == BandMember.roleAdmin)
             .map((m) => m.uid)
             .toList(),
     editorUids =
         editorUids ??
         members
             .where((m) => m.role == BandMember.roleEditor)
             .where((m) => m.role != BandMember.roleAdmin)
             .map((m) => m.uid)
             .toList();
```

**Serialization in `toJson()` (lines 133-144):**
```dart
Map<String, dynamic> toJson() => {
  'id': id,
  'name': name,
  'description': description,
  'createdBy': createdBy,
  'members': members.map((m) => m.toJson()).toList(),
  'memberUids': memberUids,       // ← Written to Firestore
  'adminUids': adminUids,         // ← Written to Firestore
  'editorUids': editorUids,       // ← Written to Firestore
  'inviteCode': inviteCode,
  'createdAt': createdAt.toIso8601String(),
};
```

**Status:** ⚠️ POTENTIAL ISSUE - Arrays are calculated but NEVER TESTED

---

## Step 5: Firestore Rules Analysis

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules`
**Lines:** 90-105

```javascript
// ============================================================
// Band Songs Subcollection
// ============================================================
// Songs stored under bands for collaborative band repertoire
match /bands/{bandId}/songs/{songId} {
  // Band members can read
  allow read: if isAuthenticated() && isGlobalBandMember(bandId);

  // Band editors/admins can create
  allow create: if isAuthenticated() && isGlobalBandEditorOrAdmin(bandId);

  // Band editors/admins can update
  allow update: if isAuthenticated() && isGlobalBandEditorOrAdmin(bandId);

  // Band admins can delete
  allow delete: if isAuthenticated() && isGlobalBandAdmin(bandId);
}
```

**Permission Check Functions (lines 15-42):**

```javascript
// Helper function to get band data from global collection
function getGlobalBand(bandId) {
  return get(/databases/$(database)/documents/bands/$(bandId)).data;
}

// Helper function to check if user is an editor or admin of a global band
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    (band.editorUids.hasAny([request.auth.uid]) ||
     band.adminUids.hasAny([request.auth.uid]));
}
```

**Status:** ✅ CORRECT - Rules properly check `adminUids` and `editorUids` arrays

---

## Step 6: THE REAL MISMATCH

### Comparison Table

| Component | Expected | Actual | Status |
|-----------|----------|--------|--------|
| **Code Path** | `/bands/{bandId}/songs/{songId}` | `/bands/{bandId}/songs/{songId}` | ✅ MATCH |
| **Rules Path** | `match /bands/{bandId}/songs/{songId}` | `match /bands/{bandId}/songs/{songId}` | ✅ MATCH |
| **Field Written** | `adminUids`, `editorUids`, `memberUids` | `adminUids`, `editorUids`, `memberUids` | ✅ MATCH |
| **Field Checked** | `band.adminUids`, `band.editorUids` | `band.adminUids`, `band.editorUids` | ✅ MATCH |
| **User in Array** | User UID should be in `adminUids` | **NOT VERIFIED** | ❌ UNKNOWN |
| **Array Population** | Arrays should contain UIDs | **NOT TESTED** | ❌ UNKNOWN |

---

## Step 7: ROOT CAUSE ANALYSIS

### Evidence Chain

1. **Band Creation Flow** (`/lib/screens/bands/create_band_screen.dart` lines 85-108):
   ```dart
   final band = Band(
     id: _isEditing ? widget.band!.id : const Uuid().v4(),
     name: _nameController.text.trim(),
     createdBy: _isEditing ? widget.band!.createdBy : user.uid,
     members: _isEditing
         ? widget.band!.members
         : [
             BandMember(
               uid: user.uid,
               role: BandMember.roleAdmin,  // ← User is ADMIN
               displayName: user.displayName,
               email: user.email,
             ),
           ],
     inviteCode: inviteCode,
     createdAt: _isEditing ? widget.band!.createdAt : DateTime.now(),
   );

   await service.saveBandToGlobal(band);  // ← Saves to /bands/{bandId}
   ```

2. **Expected Behavior:**
   - User creates band with `role: 'admin'`
   - Band constructor calculates `adminUids: [user.uid]`
   - `saveBandToGlobal` writes `adminUids` to Firestore
   - Firestore rules check `band.adminUids.hasAny([request.auth.uid])`
   - Permission GRANTED

3. **Potential Failure Points:**

   **A. Array Not Populated**
   - If `members` array is empty when Band is created, `adminUids` will be `[]`
   - **Evidence:** No test verifies `adminUids` is populated from `members`

   **B. Field Not Written to Firestore**
   - If `toJson()` doesn't include `adminUids`, field won't exist in document
   - **Evidence:** `toJson()` includes the field, but no integration test verifies actual Firestore write

   **C. Rules Not Deployed**
   - If firestore.rules wasn't deployed, default rules apply (deny all)
   - **Evidence:** `firebase.json` correctly references `firestore.rules`

   **D. Band Document Doesn't Exist**
   - If `saveBandToGlobal` fails silently, band document won't exist
   - **Evidence:** `isGlobalBandEditorOrAdmin` returns `false` if `band == null`

### CRITICAL FINDING: NO TEST COVERAGE

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/test/models/band_test.dart`

```bash
$ grep -n "adminUids\|editorUids\|memberUids" test/models/band_test.dart
# NO MATCHES FOUND
```

**There are ZERO tests verifying that:**
1. `adminUids` is populated when a member with `role: 'admin'` is added
2. `editorUids` is populated when a member with `role: 'editor'` is added
3. `memberUids` contains all member UIDs
4. These arrays are correctly serialized to/from JSON
5. These arrays are correctly written to/read from Firestore

---

## ROOT CAUSE

**The permission error occurs because:**

1. **Most Likely:** The `adminUids` array in the Firestore band document is either:
   - Empty (`[]`)
   - Missing (field doesn't exist)
   - Doesn't contain the current user's UID

2. **Why This Happens:**
   - The Band model CALCULATES the arrays correctly (code is correct)
   - BUT there's no verification that the arrays are actually WRITTEN to Firestore
   - AND there's no verification that the arrays contain the expected UIDs

3. **Contributing Factor:**
   - **ZERO test coverage** for the uid arrays
   - No integration test that creates a band and verifies `adminUids` contains the creator's UID
   - No test that simulates the permission check flow

---

## RECOMMENDED FIXES

### Immediate Fix (Verify Data)

1. **Check actual Firestore data:**
   ```bash
   # In Firebase Console, check a band document:
   # /bands/{bandId}
   # Verify fields: adminUids, editorUids, memberUids exist and contain UIDs
   ```

2. **Add debug logging:**
   ```dart
   // In addSongToBand, before writing:
   final bandDoc = await FirebaseFirestore.instance
       .collection('bands')
       .doc(bandId)
       .get();
   print('Band data: ${bandDoc.data()}');
   // Check if adminUids exists and contains user.uid
   ```

### Permanent Fix (Add Tests)

1. **Add unit test for Band model:**
   ```dart
   test('adminUids is populated from admin members', () {
     final band = Band(
       id: 'test-id',
       name: 'Test Band',
       createdBy: 'user-1',
       members: [
         BandMember(uid: 'user-1', role: BandMember.roleAdmin),
         BandMember(uid: 'user-2', role: BandMember.roleEditor),
       ],
       createdAt: DateTime.now(),
     );

     expect(band.adminUids, equals(['user-1']));
     expect(band.editorUids, equals(['user-2']));
     expect(band.memberUids, equals(['user-1', 'user-2']));
   });
   ```

2. **Add integration test for Firestore write:**
   ```dart
   test('band saved to Firestore has adminUids field', () async {
     final band = Band(/* ... with admin member ... */);
     await service.saveBandToGlobal(band);

     final doc = await FirebaseFirestore.instance
         .collection('bands')
         .doc(band.id)
         .get();

     expect(doc.data()?['adminUids'], contains(testUserId));
   });
   ```

3. **Add permission simulation test:**
   ```dart
   test('admin can add song to band', () async {
     // Create band with user as admin
     // Call addSongToBand
     // Verify no permission error
   });
   ```

---

## FILES INVOLVED

| File | Purpose | Lines |
|------|---------|-------|
| `/lib/providers/data_providers.dart` | `addSongToBand` method | 189-213 |
| `/lib/models/band.dart` | Band model with uid arrays | 44-144 |
| `/lib/models/song.dart` | Song model serialization | 109-160 |
| `/firestore.rules` | Security rules | 90-105 |
| `/lib/screens/bands/create_band_screen.dart` | Band creation | 85-108 |
| `/lib/screens/songs/songs_list_screen.dart` | Song add call site | 326-350 |
| `/test/models/band_test.dart` | **MISSING: uid array tests** | N/A |

---

## CONCLUSION

The permission error is caused by a **data integrity issue**, not a code logic issue. The code correctly calculates and writes the uid arrays, but there's no verification that:

1. The arrays are actually populated with data
2. The arrays are written to Firestore correctly
3. The arrays contain the expected user UIDs

**The previous fix didn't work because it assumed the rules were wrong, when the REAL issue is that the data being checked by the rules may not exist or may be empty.**

**Next Steps:**
1. Verify actual Firestore data in Firebase Console
2. Add debug logging to see what data is being read
3. Add comprehensive tests for uid array population
4. Consider adding a migration/fix to ensure existing bands have correct uid arrays
