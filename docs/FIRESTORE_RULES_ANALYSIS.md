# Firestore Rules Analysis: Band Songs Permission Issue

## Executive Summary

**Critical Issue Found**: Adding songs to bands is failing because the Firestore rules reference a non-existent `editorUids` field in band documents.

---

## Current Rules Structure

### Location
`/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules`

### Band Songs Subcollection Rules (Lines 88-99)
```javascript
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

---

## Helper Functions Status

### Function: `getGlobalBand(bandId)` - WORKING
```javascript
function getGlobalBand(bandId) {
  return get(/databases/$(database)/documents/bands/$(bandId)).data;
}
```
Status: Correctly fetches band document data.

### Function: `isGlobalBandMember(bandId)` - WORKING
```javascript
function isGlobalBandMember(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    band.memberUids.hasAny([request.auth.uid]);
}
```
Status: Correctly checks `memberUids` array.

### Function: `isGlobalBandAdmin(bandId)` - WORKING
```javascript
function isGlobalBandAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    band.adminUids.hasAny([request.auth.uid]);
}
```
Status: Correctly checks `adminUids` array.

### Function: `isGlobalBandEditorOrAdmin(bandId)` - BROKEN
```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    (band.editorUids.hasAny([request.auth.uid]) ||
     band.adminUids.hasAny([request.auth.uid]));
}
```
Status: **FAILS** - References non-existent `editorUids` field.

---

## Data Structure Analysis

### Band Model (`/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart`)

The Band class has the following fields:
```dart
class Band {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final List<BandMember> members;
  final List<String> memberUids;    // EXISTS - Derived from members
  final List<String> adminUids;     // EXISTS - Derived from admin members
  final String? inviteCode;
  final DateTime createdAt;
}
```

**CRITICAL**: There is NO `editorUids` field in the Band model!

### Band Member Roles
```dart
class BandMember {
  static const String roleAdmin = 'admin';
  static const String roleEditor = 'editor';    // Role exists
  static const String roleViewer = 'viewer';
}
```

---

## Identified Issues

### Issue #1: Missing `editorUids` Field (CRITICAL)

**Problem**: The Firestore rules check for `band.editorUids`, but this field does not exist in the Band model or Firestore documents.

**Location**: `firestore.rules` line 33-37

**Impact**:
1. When `isGlobalBandEditorOrAdmin()` is called, `band.editorUids` is `null`
2. Calling `.hasAny()` on `null` causes a runtime error in Firestore rules
3. The entire permission check fails
4. **NO ONE can create or update songs in band collections** (not even admins)

**Why Admins Are Also Affected**:
The rule uses OR logic:
```javascript
band.editorUids.hasAny([request.auth.uid]) ||
band.adminUids.hasAny([request.auth.uid])
```

When `band.editorUids` is `null`, calling `.hasAny()` throws an error before the `adminUids` check can be evaluated.

### Issue #2: Inconsistent Permission Model

**Problem**: The UI code in `band_songs_screen.dart` correctly checks for both admin and editor roles:
```dart
bool get _canEdit {
  final role = _userRole;
  return role == BandMember.roleAdmin || role == BandMember.roleEditor;
}
```

However, the Firestore rules cannot enforce this because `editorUids` doesn't exist.

---

## Root Cause

The Band model was designed with only `memberUids` and `adminUids` arrays for efficient Firestore rules checking. However, the rules were written to support an `editorUids` array that was never implemented in the model.

The Band model's `toJson()` method only serializes:
- `memberUids`
- `adminUids`

There is no code to generate or maintain an `editorUids` array.

---

## Recommended Fixes

### Option 1: Add `editorUids` Field to Band Model (RECOMMENDED)

**Step 1**: Update `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart`

Add the `editorUids` field:
```dart
class Band {
  // ... existing fields ...
  final List<String> memberUids;
  final List<String> adminUids;
  final List<String> editorUids;  // ADD THIS

  Band({
    // ... existing params ...
    List<String>? memberUids,
    List<String>? adminUids,
    List<String>? editorUids,  // ADD THIS
    // ...
  }) : memberUids = memberUids ?? members.map((m) => m.uid).toList(),
       adminUids = adminUids ??
           members
               .where((m) => m.role == BandMember.roleAdmin)
               .map((m) => m.uid)
               .toList(),
       editorUids = editorUids ??  // ADD THIS
           members
               .where((m) => m.role == BandMember.roleEditor)
               .where((m) => m.role != BandMember.roleAdmin) // Exclude admins
               .map((m) => m.uid)
               .toList();
```

Update `copyWith()` to recalculate `editorUids` when members change.

Update `toJson()` to include `editorUids`.

Update `fromJson()` to read `editorUids`.

**Step 2**: Update existing band documents in Firestore to include `editorUids` array.

### Option 2: Modify Rules to Check Members Array (ALTERNATIVE)

If adding `editorUids` is not desired, modify the rules to check the members array directly:

```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  if (band == null) return false;

  // Check if user is admin
  if (band.adminUids.hasAny([request.auth.uid])) return true;

  // Check if user is editor (in members with editor role)
  let member = band.members.where(m => m.uid == request.auth.uid).get(0);
  return member != null && member.role == 'editor';
}
```

**Note**: This approach may not work because Firestore rules have limited array/map manipulation capabilities.

### Option 3: Simplify to Member-Based Permissions (QUICKEST)

If editor distinction is not critical, simplify the rules:

```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  // Treat all members as editors for simplicity
  return isGlobalBandMember(bandId);
}
```

Or keep admin-only for write operations:
```javascript
allow create: if isAuthenticated() && isGlobalBandAdmin(bandId);
allow update: if isAuthenticated() && isGlobalBandAdmin(bandId);
```

---

## Verification Steps

After applying the fix:

1. **Test as Admin**: Verify admin users can add/edit/delete band songs
2. **Test as Editor**: Verify editor users can add/edit (but not delete) band songs
3. **Test as Viewer**: Verify viewer users can only read band songs
4. **Test as Non-Member**: Verify non-members cannot access band songs

---

## Files Referenced

| File | Purpose |
|------|---------|
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules` | Firestore security rules |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart` | Band data model |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/providers/data_providers.dart` | addSongToBand() implementation |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/screens/bands/band_songs_screen.dart` | UI for band songs |

---

## Conclusion

The root cause of the "adding song to band is failing" issue is the missing `editorUids` field in the Band model. The Firestore rules reference this non-existent field, causing permission checks to fail for all users.

**Recommended Action**: Implement Option 1 - Add `editorUids` field to the Band model and update existing documents.
