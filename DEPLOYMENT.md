# Firebase Deployment Guide

**Last Updated:** February 19, 2026
**Status:** ✅ Rules Deployed

---

## 📚 Related Documentation

For comprehensive build and deployment guides, see:

| Document | Description |
|----------|-------------|
| [BUILD_GUIDE.md](BUILD_GUIDE.md) | Complete build instructions for all platforms |
| [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) | Step-by-step deployment checklists |
| [RELEASE_PROCESS.md](RELEASE_PROCESS.md) | Version management and release workflow |
| [docs/PLATFORMS.md](docs/PLATFORMS.md) | Platform support and features |

---

## ✅ Completed Deployments

### Firestore Rules - DEPLOYED

**Date:** February 19, 2026  
**Command:** `firebase deploy --only firestore:rules`  
**Status:** ✅ Success

**Rules Include:**
- Global bands collection access control
- User-specific collections protection
- Band member permissions
- Admin-only update/delete rights

**Console:** [View in Firebase Console](https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules)

---

## Deployment Commands

### Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Deploy Hosting (Web App)
```bash
# Build first
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Deploy Everything
```bash
firebase deploy
```

---

## Configuration Files

### firebase.json
Configures Firebase services:
- Firestore rules location
- Hosting public directory
- Emulator ports

### .firebaserc
Firebase project configuration:
- Project ID: `repsync-app-8685c`

### firestore.rules
Security rules for Firestore database:
- Global bands collection
- User collections
- Access control

### firestore.indexes.json
Custom Firestore indexes (currently empty - no composite indexes needed)

---

## Firestore Structure

### Global Collections
```
/bands/{bandId}
  ├─ id: string
  ├─ name: string
  ├─ description: string?
  ├─ createdBy: string (UID)
  ├─ members: array
  │   └─ { uid, role, displayName, email }
  ├─ inviteCode: string (6 chars)
  └─ createdAt: timestamp
```

### User Collections
```
/users/{userId}/bands/{bandId}
  └─ Reference to global band

/users/{userId}/songs/{songId}
  └─ Song data

/users/{userId}/setlists/{setlistId}
  └─ Setlist data
```

---

## Security Rules Summary

### Global Bands (`/bands/{bandId}`)

| Operation | Permission |
|-----------|------------|
| Read | Any authenticated user |
| Create | Authenticated user who is a member |
| Update | Only band admins |
| Delete | Only band admins |

### User Collections (`/users/{userId}/...`)

| Operation | Permission |
|-----------|------------|
| Read/Write | Only the user (owner) |

---

## Testing Deployment

### Test 1: Verify Rules Deployed
1. Go to [Firebase Console](https://console.firebase.google.com/project/repsync-app-8685c/firestore/rules)
2. Check rules match `firestore.rules` file
3. Look for "Last updated" timestamp

### Test 2: Create Band
```bash
flutter run -d chrome
```
1. Login
2. Create band
3. Check Firebase Console → Firestore → `/bands/` collection
4. Band document should exist

### Test 3: Join Band
1. Get invite code from band
2. Login as different user
3. Join band with code
4. Verify:
   - User added to `/bands/{bandId}/members`
   - Reference created in `/users/{userId}/bands/`

### Test 4: Access Control
1. Try to update band as non-admin → Should fail
2. Try to delete band as admin → Should succeed
3. Try to read another user's songs → Should fail

---

## Troubleshooting

### Rules Deployment Failed

**Error:** "Compilation errors"
**Solution:**
```bash
# Check rules syntax
cat firestore.rules

# Look for:
# - Missing semicolons
# - Invalid function names
# - Type casting issues
```

### Rules Not Taking Effect

**Solution:**
1. Wait 30-60 seconds for propagation
2. Clear browser cache
3. Restart app
4. Check Firebase Console for correct version

### Permission Denied Errors

**Check:**
1. User is authenticated
2. User has correct role (admin for updates)
3. Band exists in global collection
4. User reference exists in user collection

---

## Hosting Deployment (Optional)

### Build for Web
```bash
flutter build web --release
```

### Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

### Access App
```
https://repsync-app-8685c.web.app
```

### Custom Domain (Optional)
1. Go to Firebase Console → Hosting
2. Add custom domain
3. Update DNS records
4. Wait for SSL certificate

---

## Environment Variables

### For Web Hosting

Create `web/config.js` with production credentials:
```javascript
window.env = {
  "SPOTIFY_CLIENT_ID": "your_production_id",
  "SPOTIFY_CLIENT_SECRET": "your_production_secret"
};
```

### For GitHub Pages

The app uses `.env` file embedded in build:
```bash
# Ensure .env has production credentials
cat .env

# Build
flutter build web --base-href "/flutter-repsync-app/"

# Deploy to GitHub Pages
make deploy
```

---

## Monitoring

### Firestore Usage
[Firebase Console → Firestore](https://console.firebase.google.com/project/repsync-app-8685c/firestore)

### Authentication
[Firebase Console → Authentication](https://console.firebase.google.com/project/repsync-app-8685c/authentication)

### Hosting (if deployed)
[Firebase Console → Hosting](https://console.firebase.google.com/project/repsync-app-8685c/hosting)

---

## Rollback

### Rollback Firestore Rules
```bash
# Edit firestore.rules to previous version
# Then redeploy
firebase deploy --only firestore:rules
```

### Rollback Hosting
```bash
# List previous versions
firebase hosting:releases:list

# Rollback to specific version
firebase hosting:rollback
```

---

## Best Practices

### Security
- ✅ Review rules before deploying
- ✅ Test with different user roles
- ✅ Use Firebase Emulator for local testing
- ✅ Keep credentials in `.gitignore`

### Performance
- ✅ Use indexes for complex queries
- ✅ Limit query result sizes
- ✅ Cache data on client when possible
- ✅ Use Firestore offline persistence

### Maintenance
- ✅ Monitor Firestore usage quotas
- ✅ Review security rules periodically
- ✅ Update dependencies regularly
- ✅ Test deployments before production

---

## Resources

- [Firestore Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Firestore Data Modeling](https://firebase.google.com/docs/firestore/manage-data/structure-data)

---

**Deployment Status:** ✅ Rules Deployed  
**Next Step:** Test band creation and joining functionality
