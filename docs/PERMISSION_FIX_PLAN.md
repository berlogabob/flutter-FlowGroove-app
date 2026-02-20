# Firestore Permission Error Fix Plan

**Date:** February 20, 2026
**Issue:** `[cloud_firestore/permission-denied] Missing or insuficient permissions` when adding song to band
**Status:** Ready for Implementation

---

## Root Cause Summary

The permission denied error is caused by a **missing `editorUids` field** in the Band model that is referenced by the Firestore security rules.

### The Problem Flow

1. User attempts to add a song to a band's repertoire
2. Code writes to `/bands/{bandId}/songs/{songId}`
3. Firestore evaluates the `allow create` rule
4. Rule calls `isGlobalBandEditorOrAdmin(bandId)` helper function
5. Function tries to access `band.editorUids.hasAny([request.auth.uid])`
6. **`band.editorUids` is `null`** because the field doesn't exist in Band documents
7. Calling `.hasAny()` on `null` causes rule evaluation to fail
8. **Result:** Permission denied for ALL users (including admins)

### Why This Affects Everyone

The `isGlobalBandEditorOrAdmin()` function uses OR logic:
```javascript
band.editorUids.hasAny([request.auth.uid]) ||
band.adminUids.hasAny([request.auth.uid])
```

When `band.editorUids` is `null`, the `.hasAny()` call throws an error before the `adminUids` check can be evaluated, causing the entire function to fail.

---

## Fix Options

### Option 1: Add `editorUids` Field to Band Model (RECOMMENDED)

**Description:** Add the missing `editorUids` field to the Band model to match the Firestore rules' expectations.

**Pros:**
- Maintains the intended role-based access control (RBAC) design
- Editors can add/edit songs, admins can do everything
- Consistent with existing `memberUids` and `adminUids` pattern
- No security compromise

**Cons:**
- Requires code changes to model
- Need to update existing band documents in Firestore (migration)

**Files to Modify:**
- `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart`

**Firestore Rules Changes:** None required

---

### Option 2: Simplify Rules to Check Members Array (ALTERNATIVE)

**Description:** Modify the `isGlobalBandEditorOrAdmin()` function to check the members array directly instead of using `editorUids`.

**Pros:**
- No model changes required
- No data migration needed

**Cons:**
- Firestore rules have limited array/map manipulation capabilities
- May not work reliably with complex member role checks
- More complex rule logic

**Files to Modify:**
- `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules`

**Model Changes:** None required

---

### Option 3: Simplify to Member-Based Permissions (QUICKEST)

**Description:** Allow all band members to create/update songs (remove editor distinction).

**Pros:**
- Simplest fix
- No model changes required
- Easy to understand

**Cons:**
- Loses granular permission control
- All members can add/edit songs (not just editors/admins)
- May not match business requirements

**Files to Modify:**
- `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules`

**Model Changes:** None required

---

## Recommended Approach

**Option 1: Add `editorUids` Field to Band Model**

This is the recommended approach because:
1. It maintains the intended security model with proper role separation
2. The Band model already has the infrastructure (`memberUids`, `adminUids`) for this pattern
3. The `roleEditor` constant already exists in `BandMember`
4. It's a minimal, surgical fix that addresses the root cause

---

## Step-by-Step Implementation

### Step 1: Update Band Model

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart`

**Changes:**
1. Add `editorUids` field declaration
2. Add `editorUids` parameter to constructor
3. Add `editorUids` initialization logic (derive from members with editor role)
4. Add `editorUids` to `copyWith()` method
5. Add `editorUids` to `toJson()` method
6. Add `editorUids` to `fromJson()` method

**Implementation Details:**
```dart
// Field declaration
final List<String> editorUids;

// Constructor parameter
List<String>? editorUids,

// Initialization (derive from members with editor role, exclude admins)
editorUids = editorUids ??
    members
        .where((m) => m.role == BandMember.roleEditor)
        .where((m) => m.role != BandMember.roleAdmin)
        .map((m) => m.uid)
        .toList();

// copyWith recalculation
final newEditorUids =
    editorUids ??
    newMembers
        .where((m) => m.role == BandMember.roleEditor)
        .where((m) => m.role != BandMember.roleAdmin)
        .map((m) => m.uid)
        .toList();

// toJson
'editorUids': editorUids,

// fromJson
editorUids: (json['editorUids'] as List<dynamic>?)?.cast<String>() ?? [],
```

---

### Step 2: Deploy Updated Code

**Commands:**
```bash
# Rebuild the app
flutter build apk  # or flutter build ios

# Deploy to users
# (via App Store, Play Store, or sideloading)
```

**Note:** Existing band documents in Firestore will need the `editorUids` field added. This can be done via:
1. **Manual migration script** (recommended for production)
2. **On-write trigger** (automatic but requires Cloud Functions)
3. **Lazy migration** (add field when band is next updated)

For immediate testing, the lazy migration approach works because:
- New bands will have `editorUids` automatically
- Existing bands will get `editorUids` when they're next updated
- The Firestore rules handle `null` gracefully with the `band != null` check

---

### Step 3: Deploy Firestore Rules (No Changes Required)

The existing rules are correct - they just need the data to match. However, for completeness:

```bash
firebase deploy --only firestore:rules
```

---

### Step 4: Test the Fix

**Test Scenarios:**

1. **Admin User Test:**
   - Login as band admin
   - Navigate to personal song bank
   - Select a song
   - Tap "Add to Band"
   - Select a band where user is admin
   - **Expected:** Song added successfully

2. **Editor User Test:**
   - Login as band editor (role = 'editor')
   - Navigate to personal song bank
   - Select a song
   - Tap "Add to Band"
   - Select a band where user is editor
   - **Expected:** Song added successfully

3. **Viewer User Test:**
   - Login as band viewer (role = 'viewer')
   - Navigate to personal song bank
   - Select a song
   - Tap "Add to Band"
   - Select a band where user is viewer
   - **Expected:** Permission denied (correct behavior)

4. **Non-Member Test:**
   - Login as user who is not in the band
   - Attempt to access band songs
   - **Expected:** Permission denied (correct behavior)

---

## Migration Script (Optional)

If you need to add `editorUids` to existing band documents, use this script:

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/scripts/migrate_editor_uids.js`

```javascript
// Run with: node scripts/migrate_editor_uids.js
// Requires: firebase-admin SDK and service account credentials

const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function migrateEditorUids() {
  const bands = await db.collection('bands').get();

  let updated = 0;
  for (const bandDoc of bands.docs) {
    const band = bandDoc.data();
    const members = band.members || [];

    // Calculate editorUids (editors who are not admins)
    const editorUids = members
      .filter(m => m.role === 'editor')
      .filter(m => m.role !== 'admin')
      .map(m => m.uid);

    // Only update if editorUids is different from existing
    const existingEditorUids = band.editorUids || [];
    if (JSON.stringify(editorUids.sort()) !== JSON.stringify(existingEditorUids.sort())) {
      await bandDoc.ref.update({ editorUids });
      updated++;
      console.log(`Updated band ${band.id} with editorUids: ${editorUids}`);
    }
  }

  console.log(`Migration complete. Updated ${updated} bands.`);
}

migrateEditorUids().catch(console.error);
```

---

## Rollback Plan

If issues arise after deployment:

1. **Revert Code Changes:**
   ```bash
   git revert <commit-hash>
   flutter build apk
   ```

2. **Revert Firestore Rules (if changed):**
   ```bash
   git checkout HEAD -- firestore.rules
   firebase deploy --only firestore:rules
   ```

3. **Temporary Workaround:**
   Modify rules to allow all band members to create songs:
   ```javascript
   function isGlobalBandEditorOrAdmin(bandId) {
     return isGlobalBandMember(bandId);
   }
   ```

---

## Success Criteria

- [ ] Admin users can add songs to band repertoire
- [ ] Editor users can add songs to band repertoire
- [ ] Viewer users cannot add songs (permission denied as expected)
- [ ] Non-members cannot access band songs
- [ ] No regression in existing band functionality
- [ ] No new permission errors in logs

---

## Files Referenced

| File | Action Required |
|------|-----------------|
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/models/band.dart` | **MODIFY** - Add `editorUids` field |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/firestore.rules` | No changes (rules are correct) |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/providers/data_providers.dart` | No changes (code is correct) |
| `/Users/berloga/Documents/GitHub/flutter_repsync_app/scripts/migrate_editor_uids.js` | **CREATE** (optional migration script) |

---

## Timeline

| Phase | Duration | Owner |
|-------|----------|-------|
| Code Implementation | 30 minutes | Developer |
| Testing (Local) | 30 minutes | Developer |
| Deployment | 15 minutes | DevOps |
| Testing (Production) | 1 hour | QA |
| **Total** | **~2.5 hours** | |

---

## Next Steps

1. Implement the `editorUids` field in `lib/models/band.dart`
2. Test locally with a development Firebase project
3. Deploy updated app
4. Verify fix with production data
5. Document in `PERMISSION_FIX_VERIFIED.md`
