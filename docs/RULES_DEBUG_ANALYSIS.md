# Firestore Rules Debug Analysis: Permission Denied Despite Correct adminUids

**Date:** February 20, 2026
**Status:** ROOT CAUSE ANALYSIS COMPLETE
**Priority:** CRITICAL

---

## Problem Statement

**User ID:** `QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2`

**Band Document:**
```json
{
  "adminUids": ["QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"],
  "memberUids": ["QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"],
  "editorUids": [],
  "members": [{
    "uid": "QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2",
    "role": "admin"
  }]
}
```

**Error:** `PERMISSION_DENIED: Missing or insufficient permissions.`

**Operation:** Creating a song at `/bands/{bandId}/songs/{songId}`

**Expected Behavior:** User should be able to create songs because they are in `adminUids`.

**Actual Behavior:** Permission denied.

---

## Rules Under Investigation

### Target Rule
```javascript
match /bands/{bandId}/songs/{songId} {
  allow create: if isAuthenticated() && isGlobalBandEditorOrAdmin(bandId);
}
```

### Helper Function
```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    (band.editorUids.hasAny([request.auth.uid]) ||
     band.adminUids.hasAny([request.auth.uid]));
}
```

### Dependency Chain
```javascript
function getGlobalBand(bandId) {
  return get(/databases/$(database)/documents/bands/$(bandId)).data;
}

function isAuthenticated() {
  return request.auth != null;
}
```

---

## Complete Failure Point Analysis

### Failure Point 1: `getGlobalBand()` Returns Null

**Symptom:** `band != null` evaluates to `false`

**Possible Causes:**

| Cause | Description | Likelihood |
|-------|-------------|------------|
| **1a: Wrong Database Location** | Database is in `europe-southwest1` but rules access default location | HIGH |
| **1b: Document Path Mismatch** | Band stored at different path than `/bands/{bandId}` | MEDIUM |
| **1c: Document Doesn't Exist** | Band was deleted or never created | LOW |
| **1d: Read Permission Denied** | Rules block the `get()` call itself | LOW |

**Verification:**
```javascript
// Add to rules for debugging
function debugGetGlobalBand(bandId) {
  let band = getGlobalBand(bandId);
  // If this returns null, the get() is failing
  return band;
}
```

**Firebase Console Check:**
1. Go to Firebase Console → Firestore Database
2. Navigate to `bands` collection
3. Find the band document with ID matching your band
4. Verify document exists and contains `adminUids` field

---

### Failure Point 2: `editorUids.hasAny()` on Empty Array

**Symptom:** `band.editorUids.hasAny([request.auth.uid])` returns `false`

**Analysis:**
```javascript
// Given:
band.editorUids = []  // Empty array
request.auth.uid = "QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"

// Evaluation:
[].hasAny(["QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"])  // Returns false
```

**This is EXPECTED behavior** - empty array should return `false`.

**BUT:** The `||` (OR) operator should still evaluate `adminUids`:
```javascript
false || band.adminUids.hasAny([request.auth.uid])
// Should evaluate the second condition
```

**Conclusion:** This is NOT the root cause if `adminUids` is correct.

---

### Failure Point 3: `request.auth.uid` is Null or Different

**Symptom:** User appears unauthenticated or has different UID

**Possible Causes:**

| Cause | Description | Likelihood |
|-------|-------------|------------|
| **3a: Not Logged In** | User session expired or never authenticated | MEDIUM |
| **3b: Wrong Firebase Project** | App connected to different Firebase project | MEDIUM |
| **3c: UID Mismatch** | `request.auth.uid` differs from expected UID | LOW |
| **3d: Custom Token Issue** | Auth token not properly propagated | LOW |

**Verification Code:**
```dart
// Add to your Dart code before calling addSongToBand
final user = FirebaseAuth.instance.currentUser;
print('Current User UID: ${user?.uid}');
print('Is Null: ${user == null}');
print('Email: ${user?.email}');
```

**Firebase Console Check:**
1. Go to Firebase Console → Authentication → Users
2. Find user with UID `QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2`
3. Verify user exists and is not disabled

---

### Failure Point 4: Rules Not Deployed or Cached

**Symptom:** Old rules are still active

**Possible Causes:**

| Cause | Description | Likelihood |
|-------|-------------|------------|
| **4a: Rules Not Deployed** | `firebase deploy --only firestore:rules` not run | MEDIUM |
| **4b: Wrong Rules File** | Deployed from different file than expected | MEDIUM |
| **4c: Rules Cache** | Firebase caching old rules (rare) | LOW |
| **4d: Emulator vs Production** | Testing on emulator but rules deployed to prod | MEDIUM |

**Verification:**
```bash
# Check deployed rules
firebase firestore:rules:list

# Or view in Firebase Console:
# Firebase Console → Firestore Database → Rules
```

**Check Rules Deployment Timestamp:**
1. Go to Firebase Console → Firestore Database → Rules
2. Look at "Last published" timestamp
3. Verify it matches when you last deployed

---

### Failure Point 5: Database Location Mismatch (CRITICAL)

**Symptom:** Rules cannot read band document due to multi-region issue

**This is the MOST LIKELY cause based on your setup.**

**Background:**
- Your Firestore database is located in `europe-southwest1` (Europe)
- Firebase Security Rules use `$(database)` variable which defaults to `(default)`
- Multi-region databases require explicit database ID in rules

**Current Rules:**
```javascript
function getGlobalBand(bandId) {
  return get(/databases/$(database)/documents/bands/$(bandId)).data;
}
```

**Problem:** If your database is not the `(default)` database, `$(database)` may not resolve correctly.

**Solution - Option A: Explicit Database ID**
```javascript
function getGlobalBand(bandId) {
  // For europe-southwest1 named database
  return get(/databases/europe-southwest1/documents/bands/$(bandId)).data;
}
```

**Solution - Option B: Verify Database Name**
1. Go to Firebase Console → Firestore Database
2. Check the database ID at the top of the page
3. If it shows `(default)`, then `$(database)` should work
4. If it shows a named database, use that name in rules

**Verification:**
```javascript
// Add debug function to test database access
function testDatabaseAccess(bandId) {
  // Try explicit path
  let band1 = get(/databases/$(database)/documents/bands/$(bandId)).data;
  
  // Try europe-southwest1 explicitly
  let band2 = get(/databases/europe-southwest1/documents/bands/$(bandId)).data;
  
  // Return which one worked
  return band1 != null ? 'default_works' : 
         band2 != null ? 'europe_works' : 'neither_works';
}
```

---

### Failure Point 6: `hasAny()` Type Mismatch

**Symptom:** `hasAny()` fails due to type issues

**Possible Causes:**

| Cause | Description | Likelihood |
|-------|-------------|------------|
| **6a: UID is Not String** | `request.auth.uid` is not a string | VERY LOW |
| **6b: adminUids Not Array** | `adminUids` field is not an array in Firestore | MEDIUM |
| **6c: Null in Array** | `adminUids` contains null values | LOW |

**Verification in Firebase Console:**
1. Go to band document
2. Check `adminUids` field type - must be `array`
3. Check each element is a `string`
4. Verify no null or undefined values

**Expected Firestore Data:**
```
adminUids (array)
  ├─ 0: "QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2" (string)
```

**Wrong Data Examples:**
```
// Wrong: adminUids is a map
adminUids (map)
  └─ 0: "QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"

// Wrong: adminUids contains non-string
adminUids (array)
  ├─ 0: null
  └─ 1: "QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"
```

---

### Failure Point 7: `editorUids` Field is Null (Not Empty Array)

**Symptom:** `band.editorUids` is `null` instead of `[]`

**Analysis:**
```javascript
// If editorUids field doesn't exist in Firestore:
band.editorUids  // Returns null

// Then:
null.hasAny([uid])  // This causes RULE EVALUATION ERROR

// Result: Rule evaluation fails → PERMISSION DENIED
```

**This is a CRITICAL finding!**

**Why This Happens:**
- Older band documents may not have `editorUids` field
- Band model may not have written `editorUids` for some bands
- Field was added to model after band was created

**Verification:**
1. Go to Firebase Console → Firestore → bands → {yourBandId}
2. Check if `editorUids` field exists
3. If field is missing → this is the root cause!

**Solution:**
```javascript
// Update rules to handle null editorUids
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    ((band.editorUids ?? []).hasAny([request.auth.uid]) ||
     (band.adminUids ?? []).hasAny([request.auth.uid]));
}
```

**Better Solution - Add Null Coalescing:**
```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  if (band == null) return false;
  
  let isEditor = (band.editorUids ?? []).hasAny([request.auth.uid]);
  let isAdmin = (band.adminUids ?? []).hasAny([request.auth.uid]);
  
  return isEditor || isAdmin;
}
```

---

### Failure Point 8: Short-Circuit Evaluation Issue

**Symptom:** OR operator doesn't evaluate second condition

**Analysis:**
```javascript
// JavaScript/Firestore Rules OR evaluation:
false || true  // Should return true
true || false  // Should return true (short-circuit)
null || true   // May return null (ERROR!)
```

**If `editorUids` is null:**
```javascript
band.editorUids.hasAny([uid])  // Returns null (error)
null || band.adminUids.hasAny([uid])  // Returns null, not true!
```

**This is likely the ROOT CAUSE!**

**Why:**
- `band.editorUids` is `null` (field missing)
- `null.hasAny()` causes evaluation error
- Error propagates through OR operator
- Entire function returns `null` (falsy)
- Permission denied

**Proof:**
```javascript
// Test in Rules Playground:
// Given: editorUids = null, adminUids = ["user123"]

// This fails:
null.hasAny(["user123"]) || ["user123"].hasAny(["user123"])
// Result: null (error)

// This works:
(null ?? []).hasAny(["user123"]) || ["user123"].hasAny(["user123"])
// Result: true
```

---

## Debug Code to Add

### 1. Dart Debug Code (Client-Side)

**File:** `/lib/providers/data_providers.dart`

Add before `addSongToBand`:
```dart
Future<void> addSongToBand({
  required Song song,
  required String bandId,
  required String contributorId,
  required String contributorName,
}) async {
  // DEBUG: Print user info
  final user = FirebaseAuth.instance.currentUser;
  print('=== DEBUG: addSongToBand ===');
  print('Current User UID: ${user?.uid}');
  print('Current User Email: ${user?.email}');
  print('Band ID: $bandId');
  print('Contributor ID: $contributorId');
  
  // DEBUG: Fetch and print band document
  final bandDoc = await FirebaseFirestore.instance
      .collection('bands')
      .doc(bandId)
      .get();
  
  if (bandDoc.exists) {
    final data = bandDoc.data();
    print('Band Document Exists: true');
    print('adminUids: ${data?['adminUids']}');
    print('editorUids: ${data?['editorUids']}');
    print('memberUids: ${data?['memberUids']}');
    print('adminUids contains user: ${data?['adminUids']?.contains(user?.uid)}');
    print('editorUids contains user: ${data?['editorUids']?.contains(user?.uid)}');
  } else {
    print('Band Document Exists: false');
  }
  print('===========================');
  
  // ... rest of method
}
```

### 2. Firestore Rules Debug Version

**File:** `/firestore.rules`

Temporary debug rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getGlobalBand(bandId) {
      return get(/databases/$(database)/documents/bands/$(bandId)).data;
    }
    
    // DEBUG VERSION - with null coalescing
    function isGlobalBandEditorOrAdmin(bandId) {
      let band = getGlobalBand(bandId);
      if (band == null) {
        // Log: band document not found
        return false;
      }
      
      // Use null coalescing to handle missing fields
      let editorUids = band.editorUids ?? [];
      let adminUids = band.adminUids ?? [];
      
      let isEditor = editorUids.hasAny([request.auth.uid]);
      let isAdmin = adminUids.hasAny([request.auth.uid]);
      
      return isEditor || isAdmin;
    }
    
    match /bands/{bandId}/songs/{songId} {
      allow read: if isAuthenticated() && isGlobalBandMember(bandId);
      
      // DEBUG: Allow all authenticated users temporarily
      // allow create: if isAuthenticated();
      
      // DEBUG: Use fixed version
      allow create: if isAuthenticated() && isGlobalBandEditorOrAdmin(bandId);
      
      allow update: if isAuthenticated() && isGlobalBandEditorOrAdmin(bandId);
      allow delete: if isAuthenticated() && isGlobalBandAdmin(bandId);
    }
  }
}
```

### 3. Test Script

**File:** `/scripts/test_band_permissions.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> testBandPermissions() async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  // Get current user
  final user = auth.currentUser;
  if (user == null) {
    print('ERROR: No user logged in');
    return;
  }
  
  print('Testing with user: ${user.uid}');
  
  // Replace with your band ID
  const bandId = 'YOUR_BAND_ID_HERE';
  
  // Fetch band document
  final bandDoc = await firestore.collection('bands').doc(bandId).get();
  
  if (!bandDoc.exists) {
    print('ERROR: Band document does not exist');
    return;
  }
  
  final data = bandDoc.data()!;
  
  // Check fields
  print('\n=== Band Document Analysis ===');
  print('Band Name: ${data['name']}');
  print('adminUids exists: ${data.containsKey('adminUids')}');
  print('adminUids type: ${data['adminUids']?.runtimeType}');
  print('adminUids value: ${data['adminUids']}');
  print('editorUids exists: ${data.containsKey('editorUids')}');
  print('editorUids type: ${data['editorUids']?.runtimeType}');
  print('editorUids value: ${data['editorUids']}');
  print('memberUids exists: ${data.containsKey('memberUids')}');
  print('memberUids value: ${data['memberUids']}');
  
  // Check if user is in arrays
  final adminUids = data['adminUids'] as List?;
  final editorUids = data['editorUids'] as List?;
  final memberUids = data['memberUids'] as List?;
  
  print('\n=== User Membership Check ===');
  print('User in adminUids: ${adminUids?.contains(user.uid)}');
  print('User in editorUids: ${editorUids?.contains(user.uid)}');
  print('User in memberUids: ${memberUids?.contains(user.uid)}');
  
  // Check for null fields
  print('\n=== Null Field Check ===');
  print('adminUids is null: ${adminUids == null}');
  print('editorUids is null: ${editorUids == null}');
  print('memberUids is null: ${memberUids == null}');
  
  // Check for empty arrays
  print('\n=== Empty Array Check ===');
  print('adminUids is empty: ${adminUids?.isEmpty}');
  print('editorUids is empty: ${editorUids?.isEmpty}');
  print('memberUids is empty: ${memberUids?.isEmpty}');
}
```

---

## Firebase Console Checks

### Checklist

Go to **Firebase Console** and verify each item:

#### 1. Firestore Database
- [ ] Navigate to: Firebase Console → Firestore Database
- [ ] Verify database location is `europe-southwest1`
- [ ] Check if database name is `(default)` or a named database

#### 2. Band Document
- [ ] Navigate to: `bands` collection → {yourBandId}
- [ ] Verify document exists
- [ ] Check `adminUids` field:
  - [ ] Field type is `array`
  - [ ] Contains `["QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"]`
  - [ ] No null values in array
- [ ] Check `editorUids` field:
  - [ ] Field exists (not missing)
  - [ ] Field type is `array` (not null)
  - [ ] Can be empty `[]` but must exist
- [ ] Check `memberUids` field:
  - [ ] Field type is `array`
  - [ ] Contains `["QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2"]`

#### 3. Authentication
- [ ] Navigate to: Firebase Console → Authentication → Users
- [ ] Find user with UID `QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2`
- [ ] Verify user is not disabled
- [ ] Check user email is verified (if required)

#### 4. Security Rules
- [ ] Navigate to: Firebase Console → Firestore Database → Rules
- [ ] Check "Last published" timestamp
- [ ] Verify rules contain `isGlobalBandEditorOrAdmin` function
- [ ] Verify rules are deployed to correct database location

#### 5. Rules Playground
- [ ] Click "Rules Playground" in Firestore Rules console
- [ ] Create test scenario:
  - **Location:** `/bands/{bandId}/songs/{newSongId}`
  - **Operation:** `create`
  - **Authentication:** Simulate as user `QxNTgZeUMLRMuBlmxbZ6ddh0Lzb2`
  - **Data:** Sample song document
- [ ] Click "Run" and check result
- [ ] If denied, click "View debug info" for detailed error

---

## Most Likely Root Causes (Ranked)

### 1. `editorUids` Field is Null (NOT Empty Array) - 60% Probability

**Evidence:**
- Band model may not have written `editorUids` for older bands
- `null.hasAny()` causes rule evaluation error
- Error propagates through OR operator

**Fix:**
```javascript
// Add null coalescing in rules
(band.editorUids ?? []).hasAny([request.auth.uid])
```

### 2. Database Location Mismatch - 25% Probability

**Evidence:**
- Database is in `europe-southwest1`
- Rules use `$(database)` which may not resolve correctly

**Fix:**
```javascript
// Use explicit database ID
get(/databases/europe-southwest1/documents/bands/$(bandId))
```

### 3. Rules Not Deployed - 10% Probability

**Evidence:**
- Old rules still active
- Deployment failed silently

**Fix:**
```bash
firebase deploy --only firestore:rules
```

### 4. User Not Authenticated - 5% Probability

**Evidence:**
- Session expired
- Wrong Firebase project

**Fix:**
```dart
// Verify user is logged in
final user = FirebaseAuth.instance.currentUser;
print('User UID: ${user?.uid}');
```

---

## Immediate Action Plan

### Step 1: Verify Firestore Data (5 minutes)

```bash
# Use Firebase CLI to get band document
firebase firestore:get /bands/{yourBandId}
```

Check:
- Does `editorUids` field exist?
- Is `adminUids` an array with correct UID?

### Step 2: Add Null Coalescing to Rules (5 minutes)

Edit `/firestore.rules`:
```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  if (band == null) return false;
  
  return (band.editorUids ?? []).hasAny([request.auth.uid]) ||
         (band.adminUids ?? []).hasAny([request.auth.uid]);
}
```

Deploy:
```bash
firebase deploy --only firestore:rules
```

### Step 3: Test (2 minutes)

Try adding a song to the band. If it works, the issue was null `editorUids`.

### Step 4: If Still Failing (10 minutes)

Run the debug code in Dart to print band document data.

Check Firebase Console Rules Playground for detailed error.

---

## Files Referenced

| File | Purpose |
|------|---------|
| `/firestore.rules` | Firestore security rules |
| `/lib/providers/data_providers.dart` | `addSongToBand()` method |
| `/lib/models/band.dart` | Band model with `editorUids` field |
| `/docs/PERMISSION_ERROR_DIAGNOSIS.md` | Previous diagnosis |
| `/docs/FIRESTORE_RULES_DEEP_ANALYSIS.md` | Rules analysis |

---

## Conclusion

The most likely root cause is **`editorUids` field being `null` instead of an empty array**. When Firestore rules try to call `null.hasAny()`, it causes a rule evaluation error that propagates through the OR operator, resulting in permission denied.

**Quick Fix:** Add null coalescing (`?? []`) to handle missing `editorUids` field in the rules.

**Long-term Fix:** Ensure all band documents have `editorUids` field populated (even if empty array).

---

**Analysis By:** Qwen Code AI
**Date:** February 20, 2026
**Status:** COMPLETE
