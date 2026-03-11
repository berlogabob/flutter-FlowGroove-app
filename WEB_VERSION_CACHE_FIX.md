# Web Version Display - Browser Cache Issue

## Issue

Web version shows `0.13.0` instead of `0.13.0+145` even though version.json is correct.

## Root Cause

**Browser caching** - The browser caches the old main.dart.js and version.json files.

### What's Happening

1. **Server (GitHub Pages)** has correct files:
   ```json
   // version.json
   {
     "version": "0.13.0",
     "buildNumber": "145"
   }
   ```

2. **User's browser** loads cached old files:
   ```
   Cached main.dart.js (old version)
   Cached version.json (shows 0.13.0 without build number)
   ```

3. **Profile screen** reads from cache:
   ```dart
   packageInfo.version      // "0.13.0" (from cache)
   packageInfo.buildNumber  // "" or "1" (from cache)
   ```

---

## Solution

### For Users (Immediate Fix)

**Hard Refresh** the browser to clear cache:

- **Windows/Linux:** `Ctrl + Shift + R` or `Ctrl + F5`
- **Mac:** `Cmd + Shift + R`
- **Mobile:** Clear browser cache or use incognito mode

### For Developers (Permanent Fix)

#### Option 1: Update flutter_bootstrap.js (Recommended)

Add cache-busting to the Flutter web bootstrap:

```javascript
// In docs/flutter_bootstrap.js
await main({
  serviceWorker: {
    serviceWorkerVersion: Date.now() // Force new version
  }
});
```

#### Option 2: Add Cache-Control Headers

Create `.htaccess` or `_headers` file for GitHub Pages:

```apache
# docs/_headers (for Netlify/Vercel)
/*
  Cache-Control: no-cache
```

Note: GitHub Pages doesn't support custom headers, so we need Option 3.

#### Option 3: Version-Based Cache Busting

Update the build process to add version hash to file names:

```bash
# In scripts/fix-version.sh, add:
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
cp build/web/main.dart.js docs/main-$VERSION.dart.js
```

#### Option 4: Service Worker Update

Force service worker to update on each deploy:

```javascript
// In docs/flutter_service_worker.js
const CACHE_VERSION = 'v145'; // Update with each release
```

---

## Current Status

**Files are correct:**
```bash
$ cat docs/version.json
{
  "version": "0.13.0",
  "buildNumber": "145"  # ✅ Correct!
}
```

**Profile screen code is correct:**
```dart
if (buildNumber.isNotEmpty) {
  _version = '$version+$buildNumber';  // Shows "0.13.0+145"
}
```

**Issue:** Browser cache prevents users from seeing the update.

---

## How to Verify

### 1. Check Live Site

Visit: https://berlogabob.github.io/flutter-FlowGroove-app/

Open browser DevTools → Console and run:
```javascript
fetch('version.json').then(r => r.json()).then(d => console.log(d))
```

Should show:
```json
{
  "version": "0.13.0",
  "buildNumber": "145"
}
```

### 2. Check What package_info_plus Reads

In the running web app, open DevTools Console:
```javascript
// Flutter web apps expose package info
console.log(window.flutterVersion)
```

### 3. Test in Incognito Mode

Open the site in incognito/private browsing mode - this bypasses cache and should show the correct version.

---

## Recommended Actions

### Immediate (For You)

1. **Test in incognito mode** to verify the fix works
2. **Hard refresh** your browser
3. **Clear browser cache** completely if needed

### Next Release

Add cache-busting to the release process:

```bash
# In Makefile, after copying to docs/
@echo "🔄 Clearing browser cache..."
@# Touch all JS files to force re-download
@touch docs/*.js
@# Or add timestamp to service worker
@sed -i '' "s/const CACHE_VERSION = 'v[0-9]*'/const CACHE_VERSION = 'v$(NEW_BUILD)'/" docs/flutter_service_worker.js
```

---

## Why This Happens

GitHub Pages (and most CDNs) cache static files aggressively:

- **index.html** - Cached for 10 minutes
- **main.dart.js** - Cached indefinitely (has hash in name)
- **version.json** - Cached indefinitely

When we update the app:
- ✅ New main.dart.js gets new hash (browser downloads it)
- ❌ version.json keeps same name (browser uses cached version)

---

## Best Practice

Always instruct users to hard-refresh after deployment:

```markdown
## Updated! 🎉

If you don't see the latest version:
- Press `Ctrl+Shift+R` (Windows/Linux)
- Press `Cmd+Shift+R` (Mac)
- Or clear your browser cache
```

---

## Summary

✅ **version.json is correct** in docs/  
✅ **Profile screen code is correct**  
✅ **Build process is correct**  
⚠️ **Browser cache needs to be cleared**  

**Solution:** Hard refresh browser or wait for cache to expire (usually 24 hours).

For production: Implement cache-busting in the build process.
