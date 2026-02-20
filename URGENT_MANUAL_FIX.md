# 🚨 URGENT: Manual Fix Instructions

**Do this NOW to test if the fix works (5 minutes)**

---

## Step 1: Open Firebase Console

**URL:** https://console.firebase.google.com/project/repsync-app-8685c/firestore

1. Click on **"Firestore Database"** in left menu
2. You'll see your collections

---

## Step 2: Find Your Band Document

1. Click on **"bands"** collection
2. You'll see all band documents
3. Click on the band you want to add songs to

---

## Step 3: Check Current Fields

Look at the fields in the band document. You should see:

```
members: [
  {
    uid: "your-user-id-here",
    role: "admin",
    displayName: "Your Name",
    email: "your@email.com"
  }
]
```

**Check if these fields EXIST:**
- `adminUids` (should be an array)
- `editorUids` (should be an array)
- `memberUids` (should be an array)

**If they're MISSING or EMPTY → This is the problem!**

---

## Step 4: Add Missing Fields

### Add `adminUids` Field:

1. Click **"Add field"** button
2. Field name: `adminUids`
3. Type: Select **Array**
4. Click inside the array field
5. Add your user ID (copy from members array)
6. Click **"Save"**

**Example:**
```
adminUids: ["abc123xyz456"]  ← Your actual user ID
```

### Add `memberUids` Field:

1. Click **"Add field"**
2. Field name: `memberUids`
3. Type: **Array**
4. Add ALL member UIDs (from members array)
5. Click **"Save"**

**Example:**
```
memberUids: ["abc123xyz456", "def789uvw012"]
```

### Add `editorUids` Field:

1. Click **"Add field"**
2. Field name: `editorUids`
3. Type: **Array**
4. Can be empty for now (or add editors)
5. Click **"Save"**

**Example:**
```
editorUids: []
```

---

## Step 5: Verify Fields

Your band document should now have:

```
✅ members: [{uid: "...", role: "admin", ...}]
✅ memberUids: ["..."]
✅ adminUids: ["..."]
✅ editorUids: []
```

---

## Step 6: Test Adding Song

1. **Open your RepSync app**
2. **Go to Songs screen**
3. **Select any song**
4. **Tap "Add to Band"** (or long-press)
5. **Select your band**
6. **Confirm**

**Expected Result:**
✅ **Song added successfully!**
✅ **No permission error!**

---

## Step 7: Report Results

**If it WORKS:**
- ✅ Root cause confirmed (missing uid arrays)
- ✅ Fix verified
- ✅ We can run automated fix for all bands

**If it STILL FAILS:**
- Take a screenshot of the error
- Check Firebase Rules logs
- We'll investigate further

---

## How to Find Your User ID

**Option 1: From members array**
- Copy the `uid` value from the member object

**Option 2: From Firebase Auth**
1. Go to: https://console.firebase.google.com/project/repsync-app-8685c/authentication/users
2. Find your user
3. Copy the **User UID**

**Option 3: From app logs**
- Check browser console when you log in
- Look for user object with `uid` field

---

## Expected Band Document Structure

After manual fix, your band document should look like:

```json
{
  "name": "Your Band Name",
  "description": "Band description",
  "createdBy": "abc123xyz456",
  "inviteCode": "ABC123",
  "createdAt": "2026-02-19T12:00:00.000Z",
  
  "members": [
    {
      "uid": "abc123xyz456",
      "role": "admin",
      "displayName": "Your Name",
      "email": "your@email.com"
    }
  ],
  
  "memberUids": ["abc123xyz456"],
  "adminUids": ["abc123xyz456"],
  "editorUids": []
}
```

---

## ⏰ TIME ESTIMATE

- Step 1-2: 1 minute
- Step 3: 1 minute
- Step 4: 2 minutes
- Step 5: 30 seconds
- Step 6: 1 minute

**Total: ~5 minutes**

---

## 📞 NEXT STEPS

1. **Do the manual fix NOW** (5 min)
2. **Test adding song** (1 min)
3. **Report results** in chat

**After confirmation:**
- We'll run automated fix for all bands
- Deploy updated code
- Close this issue

---

**Status:** 🔄 **AWAITING MANUAL FIX & TEST**  
**Priority:** 🔥 **CRITICAL**  
**Action Required:** YES - Do steps 1-6 NOW
