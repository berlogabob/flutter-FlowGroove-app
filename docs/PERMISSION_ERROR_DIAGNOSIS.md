# Firestore Permission Denied Error Diagnosis

## Error Details

```
Error adding song: [cloud_firestore/permission-denied] Missing or insuficient permissions.
```

**Date:** February 20, 2026  
**Feature:** Adding songs to band repertoire  
**Location:** When user attempts to add a song from their personal song bank to a band's song bank

---

## Investigation Summary

### 1. Code Path Analysis

**Method:** `addSongToBand()` in `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/providers/data_providers.dart`

**Implementation:**
```dart
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

**Collection Path Used:**
- `/bands/{bandId}/songs/{songId}`

**Data Structure Written:**
```dart
{
  'id': String,
  'title': String,
  'artist': String,
  'originalKey': String?,
  'originalBPM': int?,
  'ourKey': String?,
  'ourBPM': int?,
  'links': List<Link>,
  'notes': String?,
  'tags': List<String>,
  'bandId': String?,
  'spotifyUrl': String?,
  'createdAt': ISO8601 String,
  'updatedAt': ISO8601 String,
  'originalOwnerId': String?,
  'contributedBy': String?,
  'isCopy': bool,
  'contributedAt': ISO8601 String?,
}
```

**Call Site:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/screens/songs/songs_list_screen.dart:332`
```dart
await ref
    .read(firestoreProvider)
    .addSongToBand(
      song: song,
      bandId: bandId,
      contributorId: user.uid,
      contributorName: user.displayName ?? user.email ?? 'Unknown',
    );
```

---

### 2. Firestore Rules Analysis

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules`

**Relevant Rule:**
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

**Helper Function Used:**
```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    (band.editorUids.hasAny([request.auth.uid]) ||
     band.adminUids.hasAny([request.auth.uid]));
}
```

**Dependencies:**
- `isAuthenticated()` - Checks `request.auth != null`
- `getGlobalBand(bandId)` - Fetches band document from `/bands/{bandId}`
- `band.editorUids` - Array of editor user IDs
- `band.adminUids` - Array of admin user IDs

---

### 3. Band Model Analysis

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart`

**Current Fields:**
```dart
class Band {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final List<BandMember> members;
  final List<String> memberUids;  // ✓ EXISTS
  final List<String> adminUids;   // ✓ EXISTS
  final String? inviteCode;
  final DateTime createdAt;
  // ...
}
```

**Missing Field:**
- `editorUids` - ❌ **NOT DEFINED** in the Band model

**BandMember Roles:**
```dart
static const String roleAdmin = 'admin';
static const String roleEditor = 'editor';    // Role exists but no editorUids array
static const String roleViewer = 'viewer';
```

---

### 4. Root Cause Identified

**CRITICAL MISMATCH:** The Firestore security rules reference `band.editorUids` in the `isGlobalBandEditorOrAdmin()` helper function, but the `Band` model does **NOT** have an `editorUids` field.

**What Happens:**
1. User tries to add a song to a band
2. Code attempts to write to `/bands/{bandId}/songs/{songId}`
3. Firestore evaluates the `allow create` rule
4. Rule calls `isGlobalBandEditorOrAdmin(bandId)`
5. Function tries to access `band.editorUids.hasAny([request.auth.uid])`
6. **`band.editorUids` is `null`** because the field doesn't exist in the Band document
7. The rule evaluation fails, resulting in **permission denied**

**Why adminUids Works:**
- The `adminUids` field exists in the Band model and is properly populated
- The `isGlobalBandAdmin()` function works correctly
- Admin users can delete songs, but editors/admins cannot create or update

---

### 5. Additional Considerations

**Authentication:** The user is properly authenticated via Firebase Auth (verified in `auth_provider.dart`).

**Band Membership:** The user is likely a band member (the `memberUids` field exists and works for read permissions).

**The Real Issue:** Even if the user is an admin, the `isGlobalBandEditorOrAdmin()` function will fail because it tries to access a non-existent `editorUids` field first using the OR operator (`||`).

---

## Recommended Fix

### Option 1: Add `editorUids` Field to Band Model (Recommended)

Add the missing `editorUids` field to maintain the intended role-based access control:

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart`

```dart
class Band {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final List<BandMember> members;
  final List<String> memberUids;
  final List<String> adminUids;
  final List<String> editorUids;  // ADD THIS
  final String? inviteCode;
  final DateTime createdAt;

  Band({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.members = const [],
    List<String>? memberUids,
    List<String>? adminUids,
    List<String>? editorUids,  // ADD THIS
    this.inviteCode,
    required this.createdAt,
  }) : memberUids = memberUids ?? members.map((m) => m.uid).toList(),
       adminUids = adminUids ?? members
           .where((m) => m.role == BandMember.roleAdmin)
           .map((m) => m.uid)
           .toList(),
       editorUids = editorUids ?? members  // ADD THIS
           .where((m) => m.role == BandMember.roleEditor)
           .map((m) => m.uid)
           .toList();

  // Update copyWith to include editorUids recalculation
  // Update toJson to include editorUids
  // Update fromJson to include editorUids
}
```

### Option 2: Simplify Firestore Rules (Quick Fix)

If you don't need the editor role distinction, modify the rules to only check `adminUids`:

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules`

```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  // Simplified to only check adminUids
  return isGlobalBandAdmin(bandId);
}
```

Or allow all band members to create/update songs:

```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  // Allow all band members to add songs
  return isGlobalBandMember(bandId);
}
```

---

## Files Referenced

| File | Purpose |
|------|---------|
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/providers/data_providers.dart` | Contains `addSongToBand()` method |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules` | Firestore security rules |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart` | Band model (missing `editorUids`) |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/song.dart` | Song model |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/screens/songs/songs_list_screen.dart` | UI call site |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/providers/auth_provider.dart` | User authentication |

---

## Conclusion

The permission denied error is caused by a **missing `editorUids` field** in the Band model that is referenced by the Firestore security rules. The rules attempt to check if the user is in `band.editorUids`, but this field doesn't exist in the stored band documents, causing the rule evaluation to fail.

**Priority:** HIGH - This blocks the core feature of adding songs to band repertoire.

**Fix Complexity:** LOW - Requires adding one field to the Band model and updating the `copyWith`, `toJson`, and `fromJson` methods.
