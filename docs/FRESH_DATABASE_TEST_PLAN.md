# Fresh Database Test Plan

**Project:** RepSync App  
**Test Environment:** Fresh Database (All Users Deleted)  
**Date:** 2026-02-20  
**Firebase Project:** `repsync-app-8685c`

---

## 1. Pre-Test Setup

### 1.1 User Cleanup (DONE)
- [x] All existing users have been deleted from Firebase Auth
- [x] All user documents have been removed from Firestore
- [x] All band documents have been removed from Firestore
- [x] All song documents have been removed from Firestore

### 1.2 Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```
- [ ] Verify deployment successful
- [ ] Check rules are active in Firebase Console

### 1.3 Clear App Data/Cache
**For iOS Simulator:**
```bash
xcrun simctl uninstall booted com.example.repsync
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

**For Android Emulator:**
```bash
adb uninstall com.example.repsync
flutter run
```

**For Physical Device:**
- [ ] Uninstall app from device
- [ ] Reinstall fresh build

### 1.4 Prepare Test User Credentials

| User | Email | Password | Role | UID (to be filled) |
|------|-------|----------|------|-------------------|
| User 01 | `user01@repsync.test` | `Test1234!` | Admin | _TBD_ |
| User 02 | `user02@repsync.test` | `Test1234!` | Editor | _TBD_ |
| User 03 | `user03@repsync.test` | `Test1234!` | Viewer | _TBD_ |

---

## 2. Test Scenarios

---

### Test 1: User Registration

**Objective:** Verify new user creation in both Firebase Auth and Firestore

#### Pre-conditions
- App is freshly installed with cleared cache
- No users exist in the system

#### Steps
1. Launch the RepSync app
2. Navigate to Sign Up / Register screen
3. Enter credentials:
   - **Email:** `user01@repsync.test`
   - **Password:** `Test1234!`
   - **Confirm Password:** `Test1234!`
4. Tap "Sign Up" / "Register"
5. Complete any email verification if required
6. Wait for user document creation

#### Expected Outcome
- [ ] User successfully registered
- [ ] User is automatically logged in
- [ ] No error messages displayed

#### Firestore Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fusers

- [ ] Document exists at `/users/{user01_uid}/`
- [ ] Document contains:
  ```
  {
    email: "user01@repsync.test",
    createdAt: <timestamp>,
    updatedAt: <timestamp>,
    displayName: <string or null>,
    // ... other user fields
  }
  ```

#### Firebase Auth Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/authentication/users

- [ ] User appears in user list
- [ ] Email is `user01@repsync.test`
- [ ] Account status is active
- [ ] **Record the UID for subsequent tests:** `______________________________`

---

### Test 2: Band Creation

**Objective:** Verify band document creation with correct structure and admin assignment

#### Pre-conditions
- User01 is logged in
- User01's UID is recorded

#### Steps
1. Navigate to Bands section
2. Tap "Create Band" or "+" button
3. Enter band name: `Test Band`
4. Tap "Create" / "Save"
5. Wait for band creation to complete

#### Expected Outcome
- [ ] Band created successfully
- [ ] No error messages displayed
- [ ] User is redirected to band detail view
- [ ] Band appears in user's band list

#### Firestore Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fbands

- [ ] Document exists at `/bands/{band_id}/`
- [ ] **Record Band ID for subsequent tests:** `______________________________`

**Verify Band Document Structure:**
```
{
  name: "Test Band",
  createdAt: <timestamp>,
  updatedAt: <timestamp>,
  members: [
    {
      uid: "{user01_uid}",
      email: "user01@repsync.test",
      role: "admin",
      joinedAt: <timestamp>
    }
  ],
  memberUids: ["{user01_uid}"],
  adminUids: ["{user01_uid}"],
  editorUids: [],
  inviteCode: "<6-character code>",
  // ... other band fields
}
```

**Checklist:**
- [ ] `members` array contains user01 with role "admin"
- [ ] `memberUids` array contains user01's UID
- [ ] `adminUids` array contains user01's UID
- [ ] `editorUids` array exists (can be empty)
- [ ] `inviteCode` is generated (6 characters)
- [ ] **Record Invite Code:** `______________________________`

---

### Test 3: Create Second User

**Objective:** Create a second user for band invitation testing

#### Pre-conditions
- User01 is logged in
- Band "Test Band" exists with invite code

#### Steps
1. Log out from user01 account
2. Navigate to Sign Up / Register screen
3. Enter credentials:
   - **Email:** `user02@repsync.test`
   - **Password:** `Test1234!`
   - **Confirm Password:** `Test1234!`
4. Tap "Sign Up" / "Register"
5. Complete any email verification if required

#### Expected Outcome
- [ ] User02 successfully registered
- [ ] User02 is automatically logged in
- [ ] No error messages displayed

#### Firebase Auth Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/authentication/users

- [ ] User02 appears in user list
- [ ] Email is `user02@repsync.test`
- [ ] Account status is active
- [ ] **Record the UID for subsequent tests:** `______________________________`

---

### Test 4: Join Band

**Objective:** Verify user can join a band using invite code with correct role assignment

#### Pre-conditions
- User02 is logged in
- "Test Band" exists with recorded invite code
- User02 is NOT a member of any band

#### Steps
1. Navigate to Bands section
2. Tap "Join Band" or "Enter Invite Code"
3. Enter the invite code recorded from Test 2
4. Tap "Join" / "Submit"
5. Wait for join operation to complete

#### Expected Outcome
- [ ] User02 successfully joined the band
- [ ] No error messages displayed
- [ ] Band appears in user02's band list
- [ ] User02 can view band details

#### Firestore Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fbands/{band_id}

**Verify Band Document Updates:**
```
{
  members: [
    {
      uid: "{user01_uid}",
      email: "user01@repsync.test",
      role: "admin",
      joinedAt: <timestamp>
    },
    {
      uid: "{user02_uid}",
      email: "user02@repsync.test",
      role: "editor",
      joinedAt: <timestamp>
    }
  ],
  memberUids: ["{user01_uid}", "{user02_uid}"],
  adminUids: ["{user01_uid}"],
  editorUids: ["{user02_uid}"],
  // ... other fields
}
```

**Checklist:**
- [ ] `members` array now contains BOTH user01 (admin) and user02 (editor)
- [ ] user02's role is "editor" (NOT admin)
- [ ] `memberUids` array contains both UIDs
- [ ] `adminUids` array still contains ONLY user01's UID
- [ ] `editorUids` array now contains user02's UID
- [ ] user02's `joinedAt` timestamp is recorded

#### User Document Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fusers/{user02_uid}

- [ ] User02's document has `bandId` field set to the band's ID
- [ ] User02's document has `bandRole` field set to "editor"

---

### Test 5: Add Song to Personal Bank

**Objective:** Verify user can create songs in their personal song bank

#### Pre-conditions
- User01 is logged in
- User01 has a valid user document

#### Steps
1. Log in as user01 (`user01@repsync.test` / `Test1234!`)
2. Navigate to "My Songs" or "Personal Bank" section
3. Tap "Add Song" or "+" button
4. Enter song details:
   - **Title:** `Test Song`
   - **Artist:** `Test Artist`
   - **Key:** `C`
   - **Time Signature:** `4/4`
   - **Tempo:** `120`
   - **Notes:** `Test song for database verification`
5. Tap "Save" / "Create"

#### Expected Outcome
- [ ] Song created successfully
- [ ] No error messages displayed
- [ ] Song appears in personal song list
- [ ] Song details are correctly displayed

#### Firestore Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fusers/{user01_uid}/~2Fsongs

- [ ] Document exists at `/users/{user01_uid}/songs/{song_id}/`
- [ ] **Record Song ID:** `______________________________`

**Verify Song Document Structure:**
```
{
  title: "Test Song",
  artist: "Test Artist",
  key: "C",
  timeSignature: "4/4",
  tempo: 120,
  notes: "Test song for database verification",
  createdAt: <timestamp>,
  updatedAt: <timestamp>,
  createdBy: "{user01_uid}",
  isOriginal: false,
  // ... other song fields
}
```

**Checklist:**
- [ ] All entered fields match input
- [ ] `createdBy` field contains user01's UID
- [ ] Timestamps are correctly set

---

### Test 6: Add Song to Band (CRITICAL TEST)

**Objective:** Verify ADMIN user can add songs to band collection without permission errors

#### Pre-conditions
- User01 (admin) is logged in
- "Test Band" exists
- User01 is in `adminUids` array for the band

#### Steps
1. Ensure logged in as user01
2. Navigate to "Test Band" detail view
3. Navigate to band's "Songs" or "Setlist" section
4. Tap "Add Song" or "+" button
5. Either:
   - Select existing song "Test Song" from personal bank, OR
   - Create new song directly in band context
6. If creating new, enter:
   - **Title:** `Band Test Song`
   - **Artist:** `Band Artist`
   - **Key:** `D`
   - **Time Signature:** `4/4`
   - **Tempo:** `100`
7. Tap "Add to Band" / "Save"

#### Expected Outcome
- [ ] ✅ Song added to band successfully
- [ ] ✅ NO permission error displayed
- [ ] ✅ Song appears in band's song list
- [ ] ✅ No console errors related to Firestore permissions

#### Firestore Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fbands/{band_id}/~2Fsongs

- [ ] Document exists at `/bands/{band_id}/songs/{band_song_id}/`
- [ ] **Record Band Song ID:** `______________________________`

**Verify Band Song Document Structure:**
```
{
  title: "Band Test Song",
  artist: "Band Artist",
  key: "D",
  timeSignature: "4/4",
  tempo: 100,
  createdAt: <timestamp>,
  updatedAt: <timestamp>,
  createdBy: "{user01_uid}",
  addedBy: "{user01_uid}",
  bandId: "{band_id}",
  // ... other song fields
}
```

**Checklist:**
- [ ] Song exists in `/bands/{band_id}/songs/` collection
- [ ] `createdBy` field contains user01's UID
- [ ] `addedBy` field contains user01's UID
- [ ] `bandId` field matches the band's ID
- [ ] All entered fields match input

#### Rules Log Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules

- [ ] No DENIED entries for user01's write operations
- [ ] All write operations show ALLOWED

---

### Test 7: Editor Adds Song

**Objective:** Verify EDITOR user can add songs to band collection

#### Pre-conditions
- User02 (editor) is logged in
- User02 is in `editorUids` array for "Test Band"
- User02's role in band is "editor"

#### Steps
1. Log out from user01
2. Log in as user02 (`user02@repsync.test` / `Test1234!`)
3. Navigate to "Test Band" detail view
4. Navigate to band's "Songs" or "Setlist" section
5. Tap "Add Song" or "+" button
6. Enter song details:
   - **Title:** `Editor Test Song`
   - **Artist:** `Editor Artist`
   - **Key:** `E`
   - **Time Signature:** `4/4`
   - **Tempo:** `110`
7. Tap "Add to Band" / "Save"

#### Expected Outcome
- [ ] ✅ Song added to band successfully
- [ ] ✅ NO permission error displayed
- [ ] ✅ Song appears in band's song list
- [ ] ✅ No console errors related to Firestore permissions

#### Firestore Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fbands/{band_id}/~2Fsongs

- [ ] New document exists for "Editor Test Song"
- [ ] **Record Song ID:** `______________________________`

**Verify Song Document:**
```
{
  title: "Editor Test Song",
  artist: "Editor Artist",
  key: "E",
  timeSignature: "4/4",
  tempo: 110,
  createdAt: <timestamp>,
  updatedAt: <timestamp>,
  createdBy: "{user02_uid}",
  addedBy: "{user02_uid}",
  bandId: "{band_id}",
  // ... other song fields
}
```

**Checklist:**
- [ ] Song exists in `/bands/{band_id}/songs/` collection
- [ ] `createdBy` field contains user02's UID (editor)
- [ ] `addedBy` field contains user02's UID
- [ ] All entered fields match input

#### Rules Log Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules

- [ ] No DENIED entries for user02's write operations
- [ ] All write operations show ALLOWED

---

### Test 8: Viewer Cannot Add Song

**Objective:** Verify VIEWER user CANNOT add songs to band (permission denied)

#### Pre-conditions
- User03 (viewer) is created and added to band as viewer
- "Test Band" exists with user03 as viewer

#### Setup Steps (Before Main Test)
1. Log in as user01 (admin)
2. Navigate to "Test Band" settings/members
3. Invite user03 to band:
   - Create user03: `user03@repsync.test` / `Test1234!`
   - Send invite code to user03
   - OR manually add user03 to band with role "viewer"
4. Verify user03's role is "viewer" in Firestore

#### Firestore Setup Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fbands/{band_id}

**Verify user03 is added as viewer:**
```
{
  members: [
    // ... user01 (admin), user02 (editor)
    {
      uid: "{user03_uid}",
      email: "user03@repsync.test",
      role: "viewer",
      joinedAt: <timestamp>
    }
  ],
  memberUids: ["{user01_uid}", "{user02_uid}", "{user03_uid}"],
  adminUids: ["{user01_uid}"],
  editorUids: ["{user02_uid}"],
  viewerUids: ["{user03_uid}"],  // OR viewer role in members array
  // ... other fields
}
```

- [ ] **Record User03 UID:** `______________________________`

#### Main Test Steps
1. Log out from current user
2. Log in as user03 (`user03@repsync.test` / `Test1234!`)
3. Navigate to "Test Band" detail view
4. Navigate to band's "Songs" or "Setlist" section
5. Look for "Add Song" button
6. Attempt to add a song:
   - If "+" button visible, tap it
   - Enter song details:
     - **Title:** `Viewer Test Song`
     - **Artist:** `Viewer Artist`
   - Tap "Add to Band" / "Save"

#### Expected Outcome
- [ ] ❌ Song NOT added to band
- [ ] ❌ Permission denied error displayed OR "Add" button not visible
- [ ] ✅ Security is working correctly
- [ ] Error message is user-friendly (not exposing security details)

#### Firestore Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fbands/{band_id}/~2Fsongs

- [ ] NO new song document created by user03
- [ ] "Viewer Test Song" does NOT exist in collection

#### Rules Log Verification
Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules

- [ ] DENIED entry exists for user03's write attempt
- [ ] Denial reason relates to insufficient permissions (not admin/editor)

---

## 3. Expected Results Summary

| Test # | Test Name | Expected Result | Status |
|--------|-----------|-----------------|--------|
| 1 | User Registration | User created in Auth + Firestore | ⬜ Pass / ⬜ Fail |
| 2 | Band Creation | Band with correct uid arrays | ⬜ Pass / ⬜ Fail |
| 3 | Create Second User | User02 created successfully | ⬜ Pass / ⬜ Fail |
| 4 | Join Band | User02 added as editor | ⬜ Pass / ⬜ Fail |
| 5 | Personal Song | Song in user's personal bank | ⬜ Pass / ⬜ Fail |
| 6 | Admin Add Band Song | ✅ Song added without error | ⬜ Pass / ⬜ Fail |
| 7 | Editor Add Band Song | ✅ Song added without error | ⬜ Pass / ⬜ Fail |
| 8 | Viewer Add Band Song | ❌ Permission denied | ⬜ Pass / ⬜ Fail |

---

## 4. Success Criteria

### Database Structure Criteria
- [ ] ✅ All `uid` arrays populated correctly:
  - `memberUids` contains all member UIDs
  - `adminUids` contains only admin UIDs
  - `editorUids` contains only editor UIDs
  - `viewerUids` contains only viewer UIDs (if applicable)

### Permission Criteria
- [ ] ✅ Admin can add songs to band (Test 6 passes)
- [ ] ✅ Editor can add songs to band (Test 7 passes)
- [ ] ✅ Viewer cannot add songs to band (Test 8 passes)
- [ ] ✅ No permission errors for authorized users

### Data Integrity Criteria
- [ ] ✅ Song documents have correct `createdBy` field
- [ ] ✅ Song documents have correct `bandId` field
- [ ] ✅ Band documents maintain accurate member lists
- [ ] ✅ User documents have correct `bandId` and `bandRole` fields

### Security Criteria
- [ ] ✅ Firestore rules correctly enforce role-based access
- [ ] ✅ Rules logs show appropriate ALLOW/DENY decisions
- [ ] ✅ No unauthorized writes succeed

---

## 5. Firebase Console URLs

### Quick Links

| Console | URL |
|---------|-----|
| **Firestore Database** | https://console.firebase.google.com/project/repsync-app-8685c/firestore |
| **Authentication Users** | https://console.firebase.google.com/project/repsync-app-8685c/authentication/users |
| **Firestore Rules** | https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules |
| **Firestore Rules Logs** | https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules/logs |
| **Firebase Project Overview** | https://console.firebase.google.com/project/repsync-app-8685c/overview |

### Direct Collection Links

| Collection | URL |
|------------|-----|
| `/users/` | https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fusers |
| `/bands/` | https://console.firebase.google.com/project/repsync-app-8685c/firestore/data/~2Fbands |
| `/bands/{bandId}/songs/` | (Navigate from band document) |
| `/users/{userId}/songs/` | (Navigate from user document) |

---

## 6. Test Execution Log

### Test Run Information

| Field | Value |
|-------|-------|
| **Test Date** | ______________________________ |
| **Tester Name** | ______________________________ |
| **App Version** | ______________________________ |
| **Platform** | ⬜ iOS Simulator ⬜ Android Emulator ⬜ Physical Device |
| **Firestore Rules Version** | ______________________________ |

### Issues Found

| Issue # | Test # | Description | Severity | Status |
|---------|--------|-------------|----------|--------|
| 1 | | | ⬜ Critical ⬜ High ⬜ Medium ⬜ Low | ⬜ Open ⬜ Fixed |
| 2 | | | ⬜ Critical ⬜ High ⬜ Medium ⬜ Low | ⬜ Open ⬜ Fixed |
| 3 | | | ⬜ Critical ⬜ High ⬜ Medium ⬜ Low | ⬜ Open ⬜ Fixed |

### Notes

```
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________
```

---

## 7. Cleanup Instructions

After testing is complete, to reset for another test run:

### Delete Test Users from Firebase Auth
1. Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/authentication/users
2. Select all test users (user01, user02, user03)
3. Click "Delete" and confirm

### Delete Test Data from Firestore
1. Navigate to: https://console.firebase.google.com/project/repsync-app-8685c/firestore
2. Delete all documents in `/users/` collection
3. Delete all documents in `/bands/` collection
4. Verify all subcollections are deleted

### Clear App Data
```bash
# iOS
xcrun simctl uninstall booted com.example.repsync

# Android
adb uninstall com.example.repsync

# Or simply reinstall the app
flutter run
```

---

## Appendix A: Firestore Security Rules Reference

The tests verify the following security rules are working correctly:

### Band Songs Collection Rules
```javascript
match /bands/{bandId}/songs/{songId} {
  allow read: if isBandMember(bandId);
  allow create: if isAdminOrEditor(bandId);
  allow update, delete: if isAdmin(bandId);
}
```

### Helper Functions Expected
```javascript
function isBandMember(bandId) {
  return request.auth.uid in get(/databases/$(database)/documents/bands/$(bandId)).data.memberUids;
}

function isAdmin(bandId) {
  return request.auth.uid in get(/databases/$(database)/documents/bands/$(bandId)).data.adminUids;
}

function isEditor(bandId) {
  return request.auth.uid in get(/databases/$(database)/documents/bands/$(bandId)).data.editorUids;
}

function isAdminOrEditor(bandId) {
  return isAdmin(bandId) || isEditor(bandId);
}
```

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-20  
**Author:** RepSync Development Team
