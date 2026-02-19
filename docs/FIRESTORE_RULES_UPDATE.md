# Firestore Rules Update - Phase 2: Band Songs Subcollection

## Overview

This document describes the Phase 2 update to Firestore security rules to support the band songs subcollection with proper security controls.

## Changes Made

### 1. New Helper Function: `isGlobalBandEditorOrAdmin`

Added a new helper function to check if a user has editor or admin privileges for a band:

```javascript
function isGlobalBandEditorOrAdmin(bandId) {
  let band = getGlobalBand(bandId);
  return band != null &&
    (band.editorUids.hasAny([request.auth.uid]) ||
     band.adminUids.hasAny([request.auth.uid]));
}
```

**Purpose:** Efficiently checks if the authenticated user is either an editor or admin of the specified band using pre-computed UID arrays.

**Implementation Note:** Uses `editorUids` and `adminUids` arrays for efficient lookup, consistent with the existing `isGlobalBandMember` and `isGlobalBandAdmin` functions. This approach avoids using `filter()` which is not available in Firestore security rules.

### 2. New Rules: Band Songs Subcollection

Added security rules for the `/bands/{bandId}/songs/{songId}` subcollection:

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

## Security Model

| Operation | Required Role | Description |
|-----------|--------------|-------------|
| Read      | Band Member  | Any member of the band can view songs |
| Create    | Editor/Admin | Editors and admins can add new songs |
| Update    | Editor/Admin | Editors and admins can modify songs |
| Delete    | Admin Only   | Only admins can remove songs |

## Data Structure Requirements

For these rules to work correctly, band documents in the `/bands/{bandId}` collection must include:

- `memberUids`: Array of all member user IDs
- `editorUids`: Array of editor user IDs  
- `adminUids`: Array of admin user IDs

Example band document:
```javascript
{
  name: "The Band",
  memberUids: ["uid1", "uid2", "uid3"],
  editorUids: ["uid1", "uid2"],
  adminUids: ["uid1"]
}
```

## Deployment

Rules were deployed using:
```bash
firebase deploy --only firestore:rules
```

Deployment completed successfully with no compilation errors.

## Verification

To verify the rules are active:

1. Go to [Firebase Console](https://console.firebase.google.com/project/repsync-app-8685c/overview)
2. Navigate to Firestore Database > Rules
3. Confirm the rules match the updated `firestore.rules` file

## Related Files

- `/firestore.rules` - Updated Firestore security rules
- `/SONG_BANK_ARCHITECTURE.md` - Overall architecture documentation

## Date

February 19, 2026
