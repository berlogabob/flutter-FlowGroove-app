# GitHub Pages Version Fix

**Date:** 2026-03-15  
**Issue:** GitHub Pages showing old version (+167) after `make release` (+170)  
**Status:** ✅ **FIXED**  

---

## Root Cause

The `make release` target was **not** calling `update-version-json.sh`, so:

| Component | Source | Version |
|-----------|--------|---------|
| **Android APK** | `pubspec.yaml` | ✅ +170 (correct) |
| **GitHub Pages (Web)** | `web/version.json` | ❌ +167 (outdated) |
| **docs/version.json** | Manual copy | ❌ +167 (outdated) |

### Why This Happened

```makefile
# Before fix:
release: build-android build-appbundle
    # ❌ Never calls update-version-json.sh
    # ❌ web/version.json stays outdated
```

Only `build-web` and `build-web-github` targets called the version update script.

---

## Fix Applied

### 1. Updated Makefile `release` Target

Added call to `update-version-json.sh` in the `release` target:

```makefile
release: build-android build-appbundle
	@echo "📝 Updating version.json for GitHub Pages..."
	@./scripts/update-version-json.sh  # ✅ NOW INCLUDED
	@echo "📝 Getting version info..."
	# ... rest of release process
```

### 2. Manually Updated version.json Files

Both files updated to `0.13.2+170`:
- ✅ `web/version.json`
- ✅ `docs/version.json`

---

## Files Modified

| File | Change |
|------|--------|
| `Makefile` | Added `update-version-json.sh` call to `release` target |
| `web/version.json` | Updated to +170 |
| `docs/version.json` | Updated to +170 |

---

## Verification

Run these commands to verify:

```bash
# Check current version
cat web/version.json
cat docs/version.json

# Should show:
# {
#   "version": "0.13.2",
#   "buildNumber": "170",
#   "buildDate": "2026-03-15T15:39:49Z"
# }
```

---

## Next Release Process

When you run `make release` now:

1. ✅ Android APK builds with version from `pubspec.yaml`
2. ✅ `web/version.json` is automatically updated
3. ✅ Git commit includes updated version.json
4. ✅ GitHub Release has correct version
5. ✅ **Next** `make deploy-test` will deploy correct version to GitHub Pages

---

## Important Notes

### For Android (Obtanium)
- Version comes from `pubspec.yaml` ✅
- Obtanium reads APK metadata directly
- **No issues** - Android already shows correct version

### For Web (GitHub Pages)
- Version comes from `web/version.json` (built into web app)
- Profile screen loads version from `/version.json` endpoint
- **Was broken** - now fixed in Makefile

### Deployment Flow

```
make release:
  1. build-android → reads pubspec.yaml ✅
  2. build-appbundle → reads pubspec.yaml ✅
  3. update-version-json.sh → updates web/version.json ✅ (NEW!)
  4. git commit → includes version.json ✅
  5. git push + tag → GitHub Release ✅

make deploy-test:
  1. build-web-github → updates version.json + builds ✅
  2. copies to docs/ ✅
  3. git push to second01 branch ✅
  4. GitHub Pages updates (1-2 min) ✅
```

---

## Related Code

### Profile Screen Version Loading

```dart
// lib/screens/profile_screen.dart
Future<void> _loadVersionInfo() async {
  // On web, load from version.json
  final webVersion = await loadVersionFromJson();
  version = webVersion['version'] ?? '';
  buildNumber = webVersion['buildNumber'] ?? '';
  
  // Fallback to package_info_plus
  final packageInfo = await PackageInfo.fromPlatform();
  // ...
}
```

### Version Update Script

```bash
# scripts/update-version-json.sh
VERSION_LINE=$(grep "^version:" pubspec.yaml)
VERSION=$(echo $VERSION_LINE | sed 's/version: \([0-9.]*\)+.*/\1/')
BUILD_NUMBER=$(echo $VERSION_LINE | sed 's/version: .*+\([0-9]*\)/\1/')

# Updates web/version.json with current version
```

---

## Summary

**Problem:** `make release` didn't update `version.json`  
**Impact:** Web version showed outdated build number  
**Fix:** Added version update script to release target  
**Status:** ✅ Resolved - future releases will have correct version
