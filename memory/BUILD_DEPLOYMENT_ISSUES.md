# 🚀 BUILD & DEPLOYMENT ISSUES

**Purpose:** Document build and deployment problems

**Rule:** Review before EVERY build and deployment

---

## 1. Git Push to Wrong Branch

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED  
**Category:** git, deployment

### The Problem
Deployment script hardcoded push to `main` branch:
```bash
git push origin main  # ❌ Fails on feature branches!
```

Error:
```
! [rejected]        main -> main (non-fast-forward)
error: failed to push some refs to 'https://github.com/...'
hint: Updates were rejected because a pushed branch tip is behind
```

### Root Cause
- Script assumed deployment always from `main`
- Development was on `feature/tools-migration-backup`
- Git rejected push because local behind remote

### Impact
- Deployment failures
- Team confusion
- Risk of accidental branch overwrites

### The Fix
```bash
# scripts/deploy-all.sh - CORRECT
CURRENT_BRANCH=$(git branch --show-current)
git push origin "$CURRENT_BRANCH"
```

### Verification
```bash
# Check current branch
git branch --show-current

# Verify script uses dynamic branch
grep "CURRENT_BRANCH" scripts/deploy-all.sh
```

### Prevention
- ✅ Script detects current branch automatically
- ✅ Pushes to whatever branch you're on
- ✅ No hardcoded branch names

### Last Verified
2026-03-14 ✅

---

## 2. Duplicate Git Tags

**Date:** 2026-03-14  
**Severity:** 🟠 **HIGH**  
**Status:** ✅ FIXED  
**Category:** git, versioning

### The Problem
Script tried to create duplicate tag:
```bash
git tag -a "v0.11.2+112"  # Already exists!
git push origin "v0.11.2+112"  # Rejected
```

### Root Cause
- Tag from previous deployment existed
- Script didn't check tag location
- Tried to recreate same version

### Impact
- Deployment script failure
- Version history confusion
- Potential tag conflicts

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
- ✅ Check tag existence before creating
- ✅ Verify tag is on current branch
- ✅ Graceful handling of duplicates

### Last Verified
2026-03-14 ✅

---

## 3. Missing Deployment Scripts

**Date:** 2026-03-14  
**Severity:** 🟠 **HIGH**  
**Status:** ✅ FIXED  
**Category:** deployment, scripts

### The Problem
Critical deployment scripts missing:
- `scripts/deploy-stable` - Not found
- `scripts/deploy-all.sh` - Not found

Error:
```
make: ./scripts/deploy-stable: No such file or directory
make: *** [release-stable] Error 1
```

### Root Cause
- Scripts not committed to repository
- Lost during branch operations
- No backup of deployment scripts

### Impact
- Unable to deploy
- Makefile targets fail
- Deployment process blocked

### The Fix
Recreated scripts with full functionality:
- ✅ `scripts/deploy-stable` - Interactive wrapper
- ✅ `scripts/deploy-all.sh` - Multi-platform deployment
- ✅ Both made executable: `chmod +x`

### Prevention
- ✅ Scripts now in repository
- ✅ Committed and pushed
- ✅ Makefile targets verified

### Last Verified
2026-03-14 ✅

---

## 4. .env in Build Output

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED  
**Category:** build, security

### The Problem
`.env` file included in `build/web/`:
```bash
find build/web -name "*.env*"
# Found: build/web/.env  ❌ SECURITY BREACH!
```

### Root Cause
- `.env` in `pubspec.yaml` assets
- Flutter bundles all assets
- Build includes sensitive files

### Impact
- Credentials exposed publicly
- Security breach
- API keys compromised

### The Fix
```yaml
# pubspec.yaml - CORRECT
assets:
  - assets/sounds/
  - assets/icon.png
  # .env NOT listed!
```

### Verification Commands
```bash
# Before build
grep "\.env" pubspec.yaml  # Should not be in assets

# After build
find build/web -name "*.env*"  # Must return empty

# After deploy
curl https://your-domain.com/.env  # Must return 404
```

### Prevention Checklist
Before EVERY build:
- [ ] Check `.env` NOT in `pubspec.yaml` assets
- [ ] Verify `.env` IS in `.gitignore`

After EVERY build:
- [ ] Run: `find build/web -name "*.env*"` (must be empty)

After EVERY deployment:
- [ ] Test URL returns 404
- [ ] Check FTP for `.env` (must not exist)

### Last Verified
2026-03-14 ✅

---

## 5. Web Build Failures

**Date:** 2026-03-14  
**Severity:** 🟡 **MEDIUM**  
**Status:** ✅ FIXED  
**Category:** build, web

### The Problem
Web build fails with asset error:
```
Error detected in pubspec.yaml:
No file or variants found for asset: assets/logo_clean.png.

Target web_release_bundle failed: Exception: Failed to bundle asset files.
```

### Root Cause
- Referenced asset doesn't exist
- `logo_clean.png` not in assets folder
- Build process requires all assets to exist

### Impact
- Build fails
- Deployment blocked
- Development delayed

### The Fix
```yaml
# pubspec.yaml - Use existing assets
assets:
  - assets/sounds/
  - assets/icon.png  # This file exists
```

### Prevention
- ✅ Verify all referenced assets exist
- ✅ Run: `ls -la assets/` before build
- ✅ Update pubspec.yaml when assets change

### Last Verified
2026-03-14 ✅

---

## Build & Deployment Checklist

### Before Building:
- [ ] Read CRITICAL_PROBLEMS.md
- [ ] Check SECURITY_ISSUES.md
- [ ] Verify `.env` not in assets
- [ ] Confirm all assets exist
- [ ] Check current branch

### During Build:
- [ ] Monitor for errors
- [ ] Watch for deprecation warnings
- [ ] Verify build completes successfully

### After Build:
- [ ] Check build output clean (no `.env`)
- [ ] Verify build size reasonable
- [ ] Test locally if possible

### Before Deployment:
- [ ] Verify correct branch
- [ ] Check git status clean
- [ ] Confirm no sensitive files in build
- [ ] Review deployment script

### During Deployment:
- [ ] Monitor upload progress
- [ ] Watch for errors
- [ ] Verify all platforms deploy

### After Deployment:
- [ ] Test deployed site
- [ ] Verify `.env` returns 404
- [ ] Check all platforms working
- [ ] Monitor for errors

---

## Quick Reference Commands

```bash
# Check current branch
git branch --show-current

# Verify .env not in build
find build/web -name "*.env*"

# Test deployed site
curl -I https://flowgroove.app/.env

# Check git status
git status --short

# Verify tags
git tag -l | tail -5

# Check build size
du -sh build/web/
```

---

**Maintained By:** Mr. Memory (`mr-memory.md`)  
**Last Review:** 2026-03-14  
**Next Review:** Before next build/deployment
