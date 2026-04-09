# Create Test Accounts — Step by Step

## 1. Open Firebase Console
1. Go to https://console.firebase.google.com/
2. Select your FlowGroove project

## 2. Create Accounts

**Authentication → Users → Add user**

### Admin Account
| Field | Value |
|-------|-------|
| Email | `admin@flowgroove.app` |
| Password | `admin1234` |
| **UID** | `olBOGC6HMsZpVyTqLyfLK4GRKyZ2` |

### Demo Account
| Field | Value |
|-------|-------|
| Email | `demo@flowgroove.app` |
| Password | `demo1234` |
| **UID** | `lePjILMinYV4A0UFbg5qePv6VBg2` |

### Owner Account (optional — your real account)
| Field | Value |
|-------|-------|
| Email | `berloga.bob@gmail.com` |
| Password | *(set during account creation — not stored here)* |
| **UID** | `7RPi5xPJV5XeTm0SIWubea9DVjJ3` |

## 3. Set Access Roles in Firestore

**Firestore Database → Start collection → `users`**

Create document with ID = admin UID:
```
accessRole: "admin"
email: "admin@flowgroove.app"
displayName: "Admin Tester"
musicRoles: ["drummer", "sound_engineer"]
systemTags: ["test", "demo_seeder"]
bandIds: []
createdAt: <timestamp>
```

Create document with ID = demo UID:
```
accessRole: "demo"
email: "demo@flowgroove.app"
displayName: "Demo User"
musicRoles: ["guitarist", "vocalist"]
systemTags: ["demo", "test"]
bandIds: []
createdAt: <timestamp>
```

## 4. Run Seed Script

The UIDs are pre-filled in the script. Just confirm they're correct:

```bash
# Make sure Firebase CLI is authenticated
firebase login

# Set active project
firebase use <your-project-id>

# Run the seeder (will show UIDs and ask for confirmation)
bash scripts/seed_demo_data.sh
```

If you need to override the UIDs:
```bash
export ADMIN_UID="your_admin_uid"
export DEMO_UID="your_demo_uid"
bash scripts/seed_demo_data.sh
```

## 5. Verify

1. Open app → Login screen
2. Click **"Try Demo Account"** → should log in as demo user
3. Orange banner appears: "Demo mode — changes are not saved"
4. Try to edit a song → should be blocked
5. Sign out → login as admin → full access

---

## Quick Reference

| Account | Email | Password | accessRole | Purpose |
|---------|-------|----------|------------|---------|
| Admin | admin@flowgroove.app | admin1234 | admin | Edit content, manage band |
| Demo | demo@flowgroove.app | demo1234 | demo | Read-only exploration |
| Owner | (yours) | *(your password)* | owner | Full control |
