# 🔴 CRITICAL PROBLEMS - NEVER AGAIN

**Purpose:** Document critical issues that must never be repeated

**Rule:** Before ANY code change, review this file!

---

## 1. .env File Bundled in Web Build

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED (but verify on every build)  
**Category:** security, build

### The Problem
The `.env` file was added to `pubspec.yaml` assets, causing it to be:
- Bundled into `build/web/`
- Uploaded to FTP (flowgroove.app)
- Made publicly accessible at `https://flowgroove.app/.env`
- Exposing all API keys and secrets

### Root Cause
```yaml
# WRONG - Don't do this!
assets:
  - .env  # ❌ This bundles sensitive files!
  - assets/sounds/
```

### Impact
- **Security Breach:** All credentials exposed publicly
- **Firebase API keys** accessible to anyone
- **Spotify credentials** compromised
- **Twitter API keys** leaked
- Potential for API abuse, quota exhaustion, billing issues

### The Fix
```yaml
# CORRECT - Never bundle .env
assets:
  - assets/sounds/
  - assets/icon.png
```

### Prevention Checklist
Before EVERY web build and deployment:
- [ ] Verify `.env` is NOT in `pubspec.yaml` assets
- [ ] Check `build/web/` doesn't contain `.env`:
  ```bash
  ls -la build/web/ | grep "\.env"
  # Must return empty
  ```
- [ ] Verify `.env` is in `.gitignore`
- [ ] Test that deployed site returns 404 for `/.env`

### Files Involved
- `pubspec.yaml` - Assets configuration
- `.gitignore` - Git exclusion rules
- `lib/main.dart` - Runtime .env loading

### How to Verify Fix
```bash
# Build web
flutter build web --release

# Check build output
find build/web -name "*.env*"
# Must return nothing

# Test deployed site
curl https://flowgroove.app/.env
# Must return 404, not file content
```

### Related Memory
- `SECURITY_ISSUES.md` - Security vulnerabilities
- `BUILD_DEPLOYMENT_ISSUES.md` - Deployment problems

### Last Verified
2026-03-14 ✅

---

## 2. Git Push to Wrong Branch

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED  
**Category:** git, deployment

### The Problem
Deployment script hardcoded push to `main` branch:
```bash
git push origin main  # ❌ Wrong when on feature branch!
```

Result:
- Push rejected: `! [rejected] main -> main (non-fast-forward)`
- Deployment failed
- Confusion about which branch to deploy from

### Root Cause
Script assumed all deploys happen from `main` branch, but development was on `feature/tools-migration-backup`.

### Impact
- Deployment failures
- Risk of accidentally overwriting main branch
- Team confusion

### The Fix
```bash
# CORRECT - Push to current branch
CURRENT_BRANCH=$(git branch --show-current)
git push origin "$CURRENT_BRANCH"
```

### Prevention
- ✅ Script now detects current branch automatically
- ✅ Pushes to whatever branch you're on
- ✅ No hardcoded branch names

### Files Involved
- `scripts/deploy-all.sh` - Deployment script
- `scripts/deploy-stable` - Deployment wrapper

### Last Verified
2026-03-14 ✅

---

## 3. Duplicate Git Tags

**Date:** 2026-03-14  
**Severity:** 🟠 **HIGH**  
**Status:** ✅ FIXED  
**Category:** git, deployment

### The Problem
Script tried to create same tag twice:
```bash
git tag -a "v0.11.2+112"  # Already exists!
git push origin "v0.11.2+112"  # Rejected
```

### Root Cause
- Tag created in previous deployment
- Script didn't check if tag exists on current branch
- Tried to recreate same version tag

### Impact
- Deployment script failure
- Confusion about version history
- Potential for tag conflicts

### The Fix
```bash
# Check if tag exists and is on current branch
if ! git rev-parse "$TAG_NAME" >/dev/null 2>&1 || \
   git branch -a --contains "$TAG_NAME" | grep -q "$CURRENT_BRANCH"; then
    git push origin "$TAG_NAME" 2>/dev/null || log_warning "Tag already pushed"
else
    log_info "Tag exists on different branch, skipping tag push"
fi
```

### Prevention
- ✅ Script checks tag existence before creating
- ✅ Verifies tag is on current branch
- ✅ Graceful handling of duplicate tags

### Last Verified
2026-03-14 ✅

---

## 4. Android Deprecation Warnings

**Date:** 2026-03-14  
**Severity:** 🟡 **MEDIUM**  
**Status:** ✅ IMPROVED  
**Category:** android, dependencies

### The Problem
```
Note: Some input files use or override a deprecated API.
Note: Recompile with -Xlint:deprecation for details.
```

### Root Cause
- Old dependency versions in `pubspec.yaml`
- SDK version outdated
- Packages using deprecated Android APIs

### Impact
- Build warnings (non-fatal but concerning)
- Potential future compatibility issues
- Code quality concerns

### The Fix
Updated `pubspec.yaml`:
```yaml
environment:
  sdk: ^3.11.1  # was ^3.10.7

dependencies:
  firebase_core: ^4.5.0      # was ^4.4.0
  firebase_auth: ^6.2.0      # was ^6.1.4
  cloud_firestore: ^6.1.3    # was ^6.1.2
  flutter_riverpod: ^3.3.1   # was ^3.2.1
  audioplayers: ^6.6.0       # was ^6.5.1
  http: ^1.4.0               # was ^1.2.0
  build_runner: ^2.12.2      # was ^2.4.8
```

### Prevention
- ✅ Keep dependencies updated
- ✅ Run `flutter pub outdated` regularly
- ✅ Update SDK when major versions released

### Last Verified
2026-03-14 ✅

---

## Rules for All Future Development

### Before ANY Code Change:
1. ✅ Read this CRITICAL_PROBLEMS.md file
2. ✅ Check if change affects any known problem area
3. ✅ Verify against prevention checklists
4. ✅ Run verification commands if applicable

### Before EVERY Build:
1. ✅ Check `.env` not in assets
2. ✅ Verify build output is clean
3. ✅ Test deployed site for security

### Before EVERY Deployment:
1. ✅ Review all CRITICAL problems
2. ✅ Run verification commands
3. ✅ Confirm branch is correct
4. ✅ Check tag handling

---

**Maintained By:** Memory Guardian Agent  
**Last Review:** 2026-03-14  
**Next Review:** Every code change
