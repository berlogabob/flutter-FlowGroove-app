# Quick Firestore Data Extraction Commands

## Issue: Band A → Members expanded → Gray screen | Band B → Members expanded → Works

---

## Option 1: Firebase Console (Easiest - No Setup Required)

### Steps:

1. **Open Firebase Console**
   - Go to: https://console.firebase.google.com/
   - Select your RepSync project

2. **Navigate to Firestore**
   - Click "Firestore Database" in left sidebar
   - You'll see collections list

3. **Find Bands Collection**
   - Click on `/bands` collection
   - You'll see all band documents

4. **Export Each Band**
   - Click on a band document (e.g., "Band A")
   - Click the "JSON" tab at the top
   - Copy the entire JSON
   - Repeat for Band B

5. **Compare**
   - Paste both JSONs side by side
   - Look for differences in:
     - `members` array structure
     - `memberUids`, `adminUids`, `editorUids` arrays
     - Any null or empty string values

---

## Option 2: Firebase CLI (Fast - Requires Setup)

### Setup (One-time):

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# List your projects
firebase projects:list

# Select your project (replace with your project ID)
firebase use repsync-app-8685c
```

### Export Commands:

```bash
# Export ALL bands collection
firebase firestore:get /bands > bands_export.json

# Export specific band (replace BAND_ID)
firebase firestore:get /bands/BAND_ID > band_a_export.json

# Export as JSON (pretty printed)
firebase firestore:get /bands --format json > bands_export.json
```

### View Exported Data:

```bash
# Open in text editor
code bands_export.json

# Or view in terminal
cat bands_export.json | jq '.'  # if jq is installed
```

---

## Option 3: Browser Console (Quick - Requires App Access)

### Steps:

1. **Open your RepSync app in browser**
   - Navigate to: https://repsync-app-8685c.web.app
   - Make sure you're logged in

2. **Open Browser DevTools**
   - Chrome/Edge: F12 or Cmd+Option+I (Mac) / Ctrl+Shift+I (Windows)
   - Go to "Console" tab

3. **Run This Command:**

```javascript
// Get all bands and print as formatted JSON
firebase.firestore().collection('bands').get().then(snapshot => {
  const result = {};
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const bandName = data.name || 'Unknown';
    result[bandName] = {
      id: doc.id,
      ...data,
      members: data.members?.map((m, i) => ({
        index: i,
        uid: m.uid,
        displayName: m.displayName,
        email: m.email,
        role: m.role,
        musicRoles: m.musicRoles,
        _issues: [
          !m.uid || m.uid === '' ? 'EMPTY_UID' : null,
          (!m.displayName || m.displayName === '') && (!m.email || m.email === '') ? 'NO_DISPLAY_NAME_OR_EMAIL' : null,
          !m.role || m.role === '' ? 'EMPTY_ROLE' : null,
        ].filter(Boolean)
      })) || [],
      _memberCount: data.members?.length || 0,
      _memberUidsCount: data.memberUids?.length || 0,
      _adminUidsCount: data.adminUids?.length || 0,
      _editorUidsCount: data.editorUids?.length || 0,
    };
  });
  console.log(JSON.stringify(result, null, 2));
  
  // Also copy to clipboard
  const json = JSON.stringify(result, null, 2);
  navigator.clipboard.writeText(json).then(() => {
    console.log('\n✅ Also copied to clipboard!');
  });
});
```

4. **Copy the Output**
   - The JSON will be printed to console
   - It's also automatically copied to clipboard
   - Paste into a text file for analysis

---

## Option 4: Flutter Script (Most Detailed Analysis)

### Run the Export Script:

```bash
# Navigate to project
cd /Users/berloga/Documents/GitHub/flutter_repsync_app

# Run the analysis script
flutter run --target=scripts/export_band_data.dart
```

### Output:
- Detailed console analysis with issue detection
- JSON file export: `scripts/band_export_YYYYMMDD_HHMMSS.json`
- Side-by-side comparison table
- Recommendations for fixes

---

## What to Look For (Checklist)

### Critical Issues (Will Cause Gray Screen):

- [ ] **Empty UID**: `"uid": ""` or `"uid": null`
- [ ] **No Display Name or Email**: Both `"displayName": ""` AND `"email": ""`
- [ ] **Missing Members Array**: No `members` field at all
- [ ] **Members is Null**: `"members": null`

### High Priority Issues (May Cause Gray Screen):

- [ ] **Missing memberUids**: No `memberUids` field
- [ ] **Empty memberUids**: `"memberUids": []` but members exist
- [ ] **Missing adminUids**: No `adminUids` field (affects permissions)
- [ ] **Empty Role**: `"role": ""` or `"role": null`
- [ ] **Invalid Role**: `"role": "something_else"` (not admin/editor/viewer)

### Medium Priority Issues (Should Fix):

- [ ] **Length Mismatch**: `memberUids.length != members.length`
- [ ] **Admin Mismatch**: `adminUids` doesn't match admin members
- [ ] **Empty Display Name**: `"displayName": ""` (but has email)
- [ ] **Empty Email**: `"email": ""` (but has displayName)

---

## Example: Good vs Bad Band Data

### ✅ GOOD Band Data (Band B - Working):

```json
{
  "id": "band-b-id",
  "name": "Band B",
  "createdBy": "user123",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "members": [
    {
      "uid": "user123",
      "displayName": "John Doe",
      "email": "john@example.com",
      "role": "admin",
      "musicRoles": ["guitarist"]
    },
    {
      "uid": "user456",
      "displayName": "Jane Smith",
      "email": "jane@example.com",
      "role": "editor",
      "musicRoles": ["vocalist"]
    }
  ],
  "memberUids": ["user123", "user456"],
  "adminUids": ["user123"],
  "editorUids": ["user456"],
  "tags": ["rock", "cover"]
}
```

### ❌ BAD Band Data (Band A - Gray Screen):

```json
{
  "id": "band-a-id",
  "name": "Band A",
  "createdBy": "user123",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "members": [
    {
      "uid": "user123",
      "displayName": "",        // ⚠️ EMPTY STRING!
      "email": "",              // ⚠️ EMPTY STRING!
      "role": "admin",
      "musicRoles": ["guitarist"]
    },
    {
      "uid": "",                // ⚠️ EMPTY UID!
      "displayName": "Jane",
      "email": "jane@example.com",
      "role": "editor",
      "musicRoles": ["vocalist"]
    }
  ],
  // ⚠️ MISSING: memberUids, adminUids, editorUids
  "tags": ["rock"]
}
```

---

## Quick Fix Commands

### Fix Data via Firebase Console:

1. Go to Firebase Console → Firestore Database
2. Navigate to `/bands/{problematic_band_id}`
3. Click "Edit" (pencil icon)
4. Fix the issues:
   - Add missing `memberUids`, `adminUids`, `editorUids` arrays
   - Fix empty strings to proper values or null
5. Click "Save"

### Fix Data via Firebase CLI:

```bash
# Create a fix script
cat > fix_band.js << 'EOF'
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function fixBand(bandId) {
  const bandRef = db.collection('bands').doc(bandId);
  const band = await bandRef.get();
  const data = band.data();
  
  // Calculate correct uid arrays from members
  const members = data.members || [];
  const memberUids = members.map(m => m.uid).filter(uid => uid);
  const adminUids = members
    .filter(m => m.role === 'admin')
    .map(m => m.uid)
    .filter(uid => uid);
  const editorUids = members
    .filter(m => m.role === 'editor')
    .map(m => m.uid)
    .filter(uid => uid);
  
  // Update band document
  await bandRef.update({
    memberUids,
    adminUids,
    editorUids
  });
  
  console.log(`✅ Fixed band ${bandId}`);
  console.log(`   memberUids: ${memberUids.length}`);
  console.log(`   adminUids: ${adminUids.length}`);
  console.log(`   editorUids: ${editorUids.length}`);
}

// Replace with your band ID
fixBand('band-a-id');
EOF

# Run the fix
node fix_band.js
```

---

## After Fixing: Test

1. **Restart the app** (hot reload or full restart)
2. **Navigate to Band A**
3. **Expand members section**
4. **Verify:**
   - No gray screen
   - All members display correctly
   - Avatar initials show properly

---

## Contact/Support

If issues persist after data fix:
1. Check Firestore security rules
2. Check app logs for errors
3. Verify user permissions for the band
4. Consider code fix in `band_songs_screen.dart`

---

**Last Updated:** February 28, 2026
**Issue:** Band Members Gray Screen
