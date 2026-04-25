# 🏗️ BUILD & DEPLOYMENT ISSUES

**Purpose:** Track build and deployment problems and their resolutions
**Last Updated:** April 24, 2026
**Version:** 0.13.4+183

---

## 1. GitHub Pages Deploying to Wrong Branch (RESOLVED)

**Date:** 2026-04-02
**Severity:** 🟡 MEDIUM
**Status:** ✅ FIXED

### The Problem
GitHub Actions workflow deployed to `gh-pages` branch, but GitHub Pages was configured to serve from `docs/` folder on `second01` branch. Config.js was 404, app couldn't load Firebase config.

### The Fix
- Deleted `gh-pages` branch
- Removed GitHub Actions workflow (`.github/workflows/deploy-test.yml`)
- Using `make deploy-test` which deploys to `docs/` folder on `second01`

### Prevention
- [ ] Verify GitHub Pages source in repository settings
- [ ] Ensure deployment script targets correct branch/folder
- [ ] Test `config.js` accessibility after deploy
- [ ] Don't mix deployment methods (Actions + Makefile)

---

## 2. `docs/config.js` in `.gitignore` (RESOLVED)

**Date:** 2026-04-02
**Severity:** 🟡 MEDIUM
**Status:** ✅ FIXED

### The Problem
`/docs/config.js` was in `.gitignore`, preventing it from being committed. GitHub Pages served 404 for config.js.

### The Fix
- Removed `/docs/config.js` from `.gitignore`
- File is now committed and deployed via `docs/` folder

### Why `docs/config.js` Must Be Committed
- GitHub Pages serves from `docs/` folder
- Config.js contains Firebase config (public key, safe to commit)
- Without it, web app can't initialize Firebase

### Prevention
- [ ] Never ignore `docs/config.js` (must be deployed)
- [ ] DO ignore `web/config.js` (generated during build)
- [ ] Verify with `git status` before pushing

---

## 3. Dart JS Interop Broken After Flutter 3.41 (RESOLVED)

**Date:** 2026-04-02
**Severity:** 🔴 CRITICAL
**Status:** ✅ FIXED

### The Problem
After Flutter 3.41 web compiler update, `dart:js` interop broke:
```
NoSuchMethodError: method not found: '[]'
Receiver: Instance of 'minified:CA'
Arguments: ["env"]
```

### The Fix
- Updated `web_config.web.dart` to access `window.env` directly
- New dart2js compiler minifies JS objects, breaking `[]` operator access
- Fixed by accessing `js.context['env']` directly instead of through window

### Prevention
- [ ] Always test web config loading after Flutter updates
- [ ] Add debug logging in `getWebConfig()` for troubleshooting
- [ ] Verify `window.env` in browser console during testing

---

## 4. Duplicate Config Template Files (RESOLVED)

**Date:** 2026-04-08
**Severity:** 🟢 LOW
**Status:** ✅ FIXED

### The Problem
Three config template variants existed:
- `web/config.template.js` (modern, authoritative)
- `web/config.js.template` (legacy, empty)
- `docs/app/config.template.js` (duplicate of web)
- `docs/app/config.js.template` (legacy duplicate)

### The Fix
- Kept only `web/config.template.js` as authoritative source
- Deleted all legacy duplicates
- Added `web/config.js` to `.gitignore` (generated at build time)

---

## 5. Version Mismatch Across Documents (RESOLVED)

**Date:** 2026-04-08
**Severity:** 🟡 MEDIUM
**Status:** ✅ FIXED

### The Problem
- `pubspec.yaml`: `0.13.4+183`
- `memory/CRITICAL_PROBLEMS.md`: `0.13.5+180` (ahead of pubspec!)
- `Makefile`: `0.13.5+180`

### The Fix
- Aligned all documents to `pubspec.yaml` as single source of truth
- Updated `CRITICAL_PROBLEMS.md` and `Makefile` to `0.13.4+183`
- Updated dates to April 15, 2026

---

## 6. Production FTP Missing Hugo Landing Page (RESOLVED)

**Date:** 2026-04-15
**Severity:** 🟡 MEDIUM
**Status:** ✅ FIXED

### The Problem
`make deploy-stable` only deployed Flutter web app to FTP. Hugo landing page was absent from production (`flowgroove.app/`), only available on GitHub Pages.

### The Fix
- Added `hugo-build-prod` target — builds Hugo with `--baseURL "https://flowgroove.app/"`
- Added `build-web-prod` target — builds Flutter with `--base-href "/app/"`
- Updated `ftp-upload` — 2 lftp calls: Hugo → root, Flutter → `/app/`
- Updated `health-check-prod` — checks 3 URLs: Hugo, Flutter, config.js
- Updated documentation: `README.md`, `ARCHITECTURE.md`, `DEPLOYMENT_GUIDE.md`

### Architecture (Current - WORKING)
```
Production (flowgroove.app):
  Hugo    → / (root)   → https://flowgroove.app/
  Flutter → /app/      → https://flowgroove.app/app/

GitHub Pages (berlogabob.github.io):
  Hugo    → / (root)   → https://...github.io/...
  Flutter → /app/      → https://...github.io/.../app/

Both environments have identical structure — only baseURL differs.
```

### Prevention
- [ ] Always verify both Hugo and Flutter are deployed together
- [ ] Check `make -n deploy-stable` pipeline before changes
- [ ] Test health check URLs after deploy

---

## 7. Production FTP `/app/` Broke Again + FTP Example Leaked Credentials (RESOLVED)

**Date:** 2026-04-24
**Severity:** 🔴 CRITICAL
**Status:** ✅ FIXED

### The Problem
- `https://flowgroove.app/` returned `200`, but `https://flowgroove.app/app/` returned `404`
- production deploy still depended on ambient exported env vars instead of a canonical local source
- `build-web-prod` could silently fall back to `web/config.demo.js`
- backup/rollback used multiple timestamps per run, so the recorded backup path could drift
- `.ftp-env.example` contained real FTP credential material in tracked repo content
- `web/config.js` was still tracked in git, so the security audit failed

### The Fix
- Added `scripts/load-deploy-env.sh` as the shared loader for `.env` and optional `.ftp-env`
- Added `scripts/preflight-ftp-deploy.sh` and made `make deploy-stable` fail fast before upload when:
  - required local FTP/runtime vars are missing
  - tracked examples contain non-placeholder FTP values
  - `web/config.js` is tracked
  - blocked archive/backup/secret-bearing paths are staged
- Updated `scripts/generate-web-config.sh` to use the shared env loader and require only `FIREBASE_API_KEY`
- Updated `scripts/inject-web-config.sh` to delegate to the same canonical generator
- Removed the silent demo fallback from `build-web-prod`
- Forced demo config for GitHub/preview builds so leftover prod config cannot leak into preview output
- Fixed backup path handling to use one deploy timestamp per run
- Added a post-deploy check that `https://flowgroove.app/.env` is not publicly accessible
- Replaced `.ftp-env.example` and `.env.example` FTP values with placeholders only
- Removed tracked `web/config.js` from git index

### Acceptance Criteria
```
Production (flowgroove.app):
  Hugo    → / (root)   → https://flowgroove.app/
  Flutter → /app/      → https://flowgroove.app/app/

Required verification:
  - / returns 200
  - /app/ returns 200
  - /app/config.js returns valid runtime config
  - /.env is NOT publicly accessible
```

### Prevention
- [ ] Always run `make deploy-stable`, not ad-hoc FTP commands
- [ ] Keep FTP credentials only in `.env`, `.ftp-env`, or exported shell vars
- [ ] Keep `.env.example` and `.ftp-env.example` placeholder-only
- [ ] Do not re-add `web/config.js` to git
- [ ] Treat GitHub Pages layout parity as a release requirement for FTP production

---

## 8. Canonical FTP Target Drifted From The Actually Working `lftp` Commands (RESOLVED)

**Date:** 2026-04-24
**Severity:** 🔴 CRITICAL
**Status:** ✅ FIXED

### The Problem
Even after the live site was recovered, the checked-in `Makefile` still did not match the commands that actually worked:

- backup used `mirror $(BACKUP_DIR)/`, which is interpreted as a remote path
- Flutter upload used `mirror --reverse --delete build/web app/`, which created `app/web/` instead of uploading bundle contents into `/app/`
- rollback did not explicitly restore from the saved local backup directory

### The Fix
- backup now uses `lcd $(BACKUP_DIR); mirror . .`
- Flutter upload now uses `cd app; mirror --reverse --delete build/web/ .`
- rollback now uses `lcd $$BACKUP_DIR; mirror --reverse --delete . .`

### Durable Rule
- when `lftp` mirrors local and remote trees, always make the local/remote working directory explicit with `lcd` and `cd`
- validate `make -n deploy-stable` after any deploy-script edit; do not trust “looks right” path strings

---

## Deployment Commands Reference

```bash
# Test deployment (GitHub Pages, no credentials needed)
make -f Makefile.hugo deploy-all

# Production deployment (FTP, requires credentials)
make deploy-stable

# Android build
make release
```

---

**Last Verified:** April 24, 2026
**Version:** 0.13.4+183
