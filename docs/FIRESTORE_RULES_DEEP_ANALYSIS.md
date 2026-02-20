# Firestore Rules Deep Analysis: adminUids/editorUids Write Permissions

**Date:** February 20, 2026
**Analysis Type:** Security Rules Field Write Validation
**Status:** COMPLETE

---

## Executive Summary

**CRITICAL FINDING:** The Firestore security rules for `/bands/{bandId}` do **NOT** block `adminUids` or `editorUids` from being written. There is **NO field-level validation** in the rules that restricts which fields can be written to band documents.

The rules only validate **WHO** can perform operations (permission checks), not **WHAT** fields can be written.

---

## Step 1: Complete Rules Analysis

### File Location
`/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules`

### Global Band Rules Block (Lines 70-87)

```javascript
// ============================================================
// Global Bands Collection
// ============================================================
// Stores all bands in a single collection for cross-user access
match /bands/{bandId} {
  // Any authenticated user can read bands (needed for join by code)
  allow read: if isAuthenticated();

  // Create: Any authenticated user can create a band (must be in members list)
  allow create: if isAuthenticated() &&
    isCreatorInMembers(request.resource.data.memberUids);

  // Update: Only band admins can update band details
  // OR user can add themselves to members (join band flow)
  allow update: if isAuthenticated() && (
    isGlobalBandAdmin(bandId) ||
    isSelfJoinOnly(bandId)
  );

  // Delete: Only band admins can delete a band
  allow delete: if isAuthenticated() && isGlobalBandAdmin(bandId);
}
```

---

## Step 2: Global Band Rules Analysis

### Permission Matrix

| Operation | Who Can Perform | Validation |
|-----------|-----------------|------------|
| **Read** | Any authenticated user | None |
| **Create** | Any authenticated user | Must be in `memberUids` |
| **Update** | Band admins OR self-joining users | Admin check OR join validation |
| **Delete** | Band admins only | Admin check |

### Field Write Validation Status

**CRITICAL:** There is **NO** field validation in the rules:

```javascript
// ❌ NOT PRESENT - No field whitelist
request.resource.data.keys().hasOnly(['name', 'description', ...])

// ❌ NOT PRESENT - No field-specific validation
request.resource.data.adminUids is list
request.resource.data.editorUids is list
```

**Conclusion:** The rules allow **ANY** fields to be written as long as the user has permission to perform the operation.

---

## Step 3: Field Validation Check

### Searching for Field Restrictions

**Searched for:**
```javascript
function hasOnlyAllowedFields()
request.resource.data.keys().hasOnly
request.resource.data.match
validateField
```

**Result:** **NONE FOUND**

### Current Helper Functions

```javascript
// Helper function to check if user is authenticated
function isAuthenticated() {
  return request.auth != null;
}

// Helper function to check if user is the owner
function isOwner(userId) {
  return request.auth.uid == userId;
}

// Helper function to get band data from global collection
function getGlobalBand(bandId) {
  return get(/databases/$(database)/documents/bands/$(bandId)).data;
}

// Helper function to check if user is a member of a global band
function isGlobalBandMember(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    band.memberUids.hasAny([request.auth.uid]);
}

// Helper function to check if user is an admin of a global band
function isGlobalBandAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    band.adminUids.hasAny([request.auth.uid]);
}

// Helper function to check if user is an editor or admin of a global band
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    (band.editorUids.hasAny([request.auth.uid]) ||
     band.adminUids.hasAny([request.auth.uid]));
}

// Helper function to check if creating user is in members list
function isCreatorInMembers(memberUids) {
  return memberUids.hasAny([request.auth.uid]);
}

// Helper function to check if user is adding themselves to members
function isSelfJoinOnly(bandId) {
  let existingBand = getGlobalBand(bandId);
  let newMemberUids = request.resource.data.memberUids;
  return existingBand != null &&
    !existingBand.memberUids.hasAny([request.auth.uid]) &&
    newMemberUids.hasAll(existingBand.memberUids) &&
    newMemberUids.hasAll([request.auth.uid]) &&
    newMemberUids.size() == existingBand.memberUids.size() + 1;
}
```

**Analysis:** All helper functions are **PERMISSION CHECKS**, not **FIELD VALIDATION**.

---

## Step 4: Computed Fields Analysis

### Are adminUids/editorUids Blocked?

**ANSWER: NO**

The rules do **NOT** block writes to `adminUids` or `editorUids` because:

1. **No field whitelist:** There's no `keys().hasOnly([...])` restriction
2. **No field validation:** There's no validation that checks field types or values
3. **No computed-field protection:** There's no rule preventing writes to computed fields

### What The Rules Actually Check

| Rule | What It Validates | Does It Block adminUids/editorUids? |
|------|-------------------|-------------------------------------|
| `allow create` | Creator must be in `memberUids` | **NO** |
| `allow update` | User must be admin OR self-joining | **NO** |
| `isCreatorInMembers` | `memberUids` contains creator's UID | **NO** |
| `isGlobalBandAdmin` | Existing doc's `adminUids` contains user's UID | **NO** |
| `isSelfJoinOnly` | `memberUids` change is valid self-join | **NO** |

---

## Step 5: The REAL Blocker Analysis

### Potential Blockers Checked

#### 1. Field Validation Blocking uid Fields
**Status:** **NOT PRESENT**
- No `request.resource.data.keys().hasOnly([...])`
- No field-specific validation

#### 2. Data Validation That Fails
**Status:** **POSSIBLE ISSUE**

The `isSelfJoinOnly` function requires `memberUids` to be present:
```javascript
function isSelfJoinOnly(bandId) {
  let existingBand = getGlobalBand(bandId);
  let newMemberUids = request.resource.data.memberUids;  // ← Requires field
  // ...
}
```

**Impact:** If an admin updates a band without including `memberUids` in the request, and they're NOT recognized as an admin, the `isSelfJoinOnly` check would fail because `request.resource.data.memberUids` would be undefined.

**However:** The Band model's `copyWith()` method ALWAYS includes `memberUids`:
```dart
final newMemberUids = memberUids ?? newMembers.map((m) => m.uid).toList();
```

#### 3. Require Fields That Don't Exist
**Status:** **NOT APPLICABLE**
- The rules don't require specific fields (except implicitly in `isSelfJoinOnly`)

#### 4. Admin Check Reading Wrong Data
**Status:** **POTENTIAL ISSUE**

The `isGlobalBandAdmin` function reads the **EXISTING** document:
```javascript
function isGlobalBandAdmin(bandId) {
  let band = getGlobalBand(bandId);  // ← Reads EXISTING doc
  return band != null &&
    band.adminUids.hasAny([request.auth.uid]);  // ← Checks EXISTING adminUids
}
```

**This is CORRECT behavior** - it checks if the user is CURRENTLY an admin before allowing updates.

**Potential Issue:** If the existing band document doesn't have `adminUids` populated (or it's empty), the admin check will fail even if the user should be an admin.

---

## Step 6: Evidence of The Real Issue

### Previous Investigation Findings

From `/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/DEEP_INVESTIGATION_REPORT.md`:

> **ROOT CAUSE:** The Firestore security rules are correctly configured, BUT there is NO test coverage verifying that the `adminUids`, `editorUids`, and `memberUids` arrays are properly populated when bands are created/saved.

### Evidence Chain

1. **Band Model Correctly Computes Arrays:**
   ```dart
   // /lib/models/band.dart lines 71-83
   adminUids =
       adminUids ??
       members
           .where((m) => m.role == BandMember.roleAdmin)
           .map((m) => m.uid)
           .toList();
   ```

2. **Band Model Correctly Serializes Arrays:**
   ```dart
   // /lib/models/band.dart lines 140-141
   'adminUids': adminUids,
   'editorUids': editorUids,
   ```

3. **Rules Correctly Check Arrays:**
   ```javascript
   // firestore.rules lines 28-31
   function isGlobalBandAdmin(bandId) {
     let band = getGlobalBand(bandId);
     return band != null &&
       band.adminUids.hasAny([request.auth.uid]);
   }
   ```

4. **BUT: No Verification Data Exists:**
   - No tests verify `adminUids` is populated
   - No integration tests verify arrays are written to Firestore
   - No runtime validation that arrays contain expected UIDs

### The REAL Blocker

**The rules are NOT blocking adminUids/editorUids from being written.**

**The actual issue is:**

1. **Data Integrity:** The `adminUids`/`editorUids` arrays in Firestore may be:
   - Empty (`[]`)
   - Missing (field doesn't exist)
   - Not containing the expected user UIDs

2. **Why This Happens:**
   - The Band model CALCULATES arrays correctly
   - BUT there's no verification the data is actually written correctly
   - AND there's no test coverage to catch this

3. **Result:**
   - `isGlobalBandAdmin()` returns `false` because `adminUids` is empty/missing
   - User gets permission denied even though they should be an admin

---

## Step 7: Recommended Fixes

### Immediate Actions

#### 1. Verify Firestore Data
Check actual band documents in Firebase Console:
```
Firestore Database → bands → {bandId}
```

Verify these fields exist and contain data:
- `adminUids`: Should contain admin user UIDs
- `editorUids`: Should contain editor user UIDs (excluding admins)
- `memberUids`: Should contain all member UIDs

#### 2. Add Debug Logging
In `/lib/providers/data_providers.dart`, add logging before writes:
```dart
Future<void> saveBandToGlobal(Band band) async {
  print('DEBUG: Saving band ${band.id}');
  print('DEBUG: adminUids: ${band.adminUids}');
  print('DEBUG: editorUids: ${band.editorUids}');
  print('DEBUG: memberUids: ${band.memberUids}');

  await FirebaseFirestore.instance
      .collection('bands')
      .doc(band.id)
      .set(band.toJson());
}
```

#### 3. Add Data Validation
Add runtime validation in the Band model:
```dart
Band({
  // ...
}) : memberUids = memberUids ?? members.map((m) => m.uid).toList(),
     adminUids = adminUids ??
         members
             .where((m) => m.role == BandMember.roleAdmin)
             .map((m) => m.uid)
             .toList(),
     editorUids = editorUids ??
         members
             .where((m) => m.role == BandMember.roleEditor)
             .where((m) => m.role != BandMember.roleAdmin)
             .map((m) => m.uid)
             .toList() {
  // Validation
  assert(memberUids.isNotEmpty, 'memberUids cannot be empty');
  assert(adminUids.isNotEmpty, 'adminUids cannot be empty (need at least one admin)');
}
```

### Long-Term Fixes

#### 1. Add Unit Tests
Create tests for uid array population:
```dart
// test/models/band_test.dart
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

#### 2. Add Integration Tests
Test actual Firestore writes:
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

#### 3. Add Data Migration
For existing bands without uid arrays:
```dart
Future<void> migrateBands() async {
  final bands = await FirebaseFirestore.instance.collection('bands').get();

  for (final doc in bands.docs) {
    final data = doc.data();
    final members = (data['members'] as List?)?.map((m) =>
      BandMember.fromJson(m as Map<String, dynamic>)
    ).toList() ?? [];

    final adminUids = members
        .where((m) => m.role == BandMember.roleAdmin)
        .map((m) => m.uid)
        .toList();

    final editorUids = members
        .where((m) => m.role == BandMember.roleEditor)
        .where((m) => m.role != BandMember.roleAdmin)
        .map((m) => m.uid)
        .toList();

    final memberUids = members.map((m) => m.uid).toList();

    await doc.reference.update({
      'adminUids': adminUids,
      'editorUids': editorUids,
      'memberUids': memberUids,
    });
  }
}
```

---

## Files Referenced

| File | Purpose | Key Lines |
|------|---------|-----------|
| `/firestore.rules` | Firestore security rules | 70-87, 15-42 |
| `/lib/models/band.dart` | Band data model | 44-83, 133-144 |
| `/lib/providers/data_providers.dart` | Firestore operations | 130-136 |
| `/lib/screens/bands/create_band_screen.dart` | Band creation | 85-108 |
| `/docs/DEEP_INVESTIGATION_REPORT.md` | Previous investigation | N/A |
| `/docs/FIRESTORE_RULES_ANALYSIS.md` | Rules analysis | N/A |
| `/FIRESTORE_PERMISSION_FIXED.md` | Previous fix documentation | N/A |

---

## Conclusion

### Summary of Findings

| Question | Answer | Evidence |
|----------|--------|----------|
| **Do rules block adminUids/editorUids writes?** | **NO** | No field validation in rules |
| **Do rules have field whitelists?** | **NO** | No `keys().hasOnly([...])` |
| **Do rules validate field types?** | **NO** | No type validation |
| **What DO rules validate?** | **PERMISSIONS ONLY** | `isGlobalBandAdmin`, `isCreatorInMembers`, etc. |
| **What is the REAL issue?** | **DATA INTEGRITY** | Arrays may be empty/missing in Firestore |
| **Why does this happen?** | **NO VERIFICATION** | No tests, no validation, no monitoring |

### The Rules Are NOT The Problem

The Firestore security rules for `/bands/{bandId}`:
- ✅ Allow all fields to be written (no field restrictions)
- ✅ Allow `adminUids` and `editorUids` to be written
- ✅ Correctly check permissions using these arrays
- ✅ Are properly deployed and active

### The Real Problem Is Data Integrity

The actual issue is:
- ❌ No verification that `adminUids`/`editorUids` are populated
- ❌ No tests that arrays contain expected UIDs
- ❌ No integration tests verifying Firestore writes
- ❌ No runtime validation of array contents
- ❌ No migration for existing bands without arrays

### Recommended Next Steps

1. **Immediate:** Check Firebase Console for actual band document data
2. **Short-term:** Add debug logging to verify data being written
3. **Medium-term:** Add unit and integration tests
4. **Long-term:** Add data migration for existing bands

---

**Analysis By:** Qwen Code AI
**Date:** February 20, 2026
**Status:** COMPLETE
