# 🔥 URGENT: Permission Error Debug Plan

**Issue:** `[cloud_firestore/permission-denied]` when adding song to band  
**Status:** 🔄 **INVESTIGATING**  
**Previous Fix:** ❌ Did not work

---

## What We Know (From Deep Analysis)

### ✅ Code is CORRECT

1. **addSongToBand()** writes to `/bands/{bandId}/songs/{songId}` ✅
2. **Band model** auto-calculates adminUids/editorUids from members ✅
3. **Firestore rules** check `isGlobalBandEditorOrAdmin(bandId)` ✅
4. **Rules do NOT block** adminUids/editorUids fields ✅

### ❌ The REAL Problem

**Hypothesis:** Band documents in Firestore have EMPTY or MISSING `adminUids`/`editorUids` fields.

**Why previous fix didn't work:**
- The Band model CALCULATES the fields correctly
- BUT existing band documents in Firestore may not have these fields
- When rules check `band.adminUids.hasAny([userId])`, it returns FALSE
- Permission is DENIED even for admins

---

## Root Cause Theory

### Scenario 1: Old Band Documents

Bands created BEFORE the `adminUids`/`editorUids` logic was added:
```javascript
// Firestore document:
{
  name: "My Band",
  members: [
    { uid: "user123", role: "admin" }
  ]
  // ❌ adminUids field MISSING
  // ❌ editorUids field MISSING
}
```

**Result:** Rules fail because `band.adminUids` is `null` or `[]`

### Scenario 2: Serialization Issue

Band model calculates fields, but they're not being saved:
```dart
// Band model has:
adminUids: ['user123'] ✅

// But Firestore has:
adminUids: null ❌
```

**Possible causes:**
- `toJson()` not including fields
- Firestore rules blocking writes
- Network issue during save

### Scenario 3: User Not In Members Array

User trying to add song is NOT in the band's members array:
```dart
members: [
  { uid: "other_user", role: "admin" }
]
// Current user's UID is NOT here!
```

**Result:** `isGlobalBandMember()` returns false → Permission denied

---

## Debug Steps

### Step 1: Check ACTUAL Firestore Data

Run debug script:
```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app

# Option A: Use Firebase Console (manual)
# Go to: https://console.firebase.google.com/project/repsync-app-8685c/firestore

# Option B: Use debug script (automated)
firebase login
flutter run scripts/debug_band_data.dart
```

**What to look for:**
- `adminUids` field exists?
- `editorUids` field exists?
- Current user's UID in adminUids?
- Current user in members array?

### Step 2: Add Logging to Code

Add print statements in `addSongToBand()`:

```dart
Future<void> addSongToBand({
  required Song song,
  required String bandId,
  required String contributorId,
  required String contributorName,
}) async {
  // DEBUG: Print what we're sending
  print('🔍 DEBUG: Adding song to band');
  print('   Band ID: $bandId');
  print('   Contributor ID: $contributorId');
  
  // Check band document
  final bandDoc = await FirebaseFirestore.instance
      .collection('bands')
      .doc(bandId)
      .get();
  
  final bandData = bandDoc.data()!;
  print('   Band name: ${bandData['name']}');
  print('   adminUids: ${bandData['adminUids']}');
  print('   editorUids: ${bandData['editorUids']}');
  print('   memberUids: ${bandData['memberUids']}');
  print('   Members: ${bandData['members']}');
  
  // ... rest of method
}
```

### Step 3: Check Firebase Console Logs

Go to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules

Check:
- Rules execution logs
- Which condition failed
- What data was checked

---

## Immediate Fixes

### Fix 1: Migration Script (If fields are missing)

Run if debug shows missing fields:
```bash
node scripts/migrate_editor_uids.js
```

### Fix 2: Manual Firestore Update (Quick fix for testing)

In Firebase Console:
1. Go to Firestore Database
2. Select band document
3. Add field: `adminUids` (array)
4. Add creator's UID to array
5. Try adding song again

### Fix 3: Update Band Document (If user not in members)

```dart
// In Firebase Console or via script:
// Add user to members array with appropriate role
members: [
  ...existingMembers,
  { uid: currentUserId, role: 'admin' }
]
```

---

## Testing Checklist

After fix:
- [ ] Debug script shows adminUids has user's UID
- [ ] Debug script shows user in members array with admin role
- [ ] Try adding song to band
- [ ] No permission error
- [ ] Song appears in band's songs

---

## Files to Check

| File | Purpose |
|------|---------|
| `scripts/debug_band_data.dart` | Debug script |
| `scripts/migrate_editor_uids.js` | Migration script |
| `docs/DEEP_INVESTIGATION_REPORT.md` | Full investigation |
| `docs/BAND_CREATION_ANALYSIS.md` | Band creation analysis |
| `docs/FIRESTORE_RULES_DEEP_ANALYSIS.md` | Rules analysis |

---

**Next Action:** Run debug script and check ACTUAL data in Firestore!
