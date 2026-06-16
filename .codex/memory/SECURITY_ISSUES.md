# 🔒 SECURITY ISSUES

**Purpose:** Track security vulnerabilities and their resolutions
**Last Updated:** April 8, 2026
**Version:** 0.13.4+183

---

## 1. `.env` File Bundled in Web Build (CRITICAL - RESOLVED)

**Date:** 2026-03-14
**Severity:** 🔴 CRITICAL
**Status:** ✅ FIXED

### The Problem
`.env` was added to `pubspec.yaml` assets section, causing Firebase API keys, Spotify credentials, and Twitter keys to be publicly accessible at `https://flowgroove.app/.env`.

### The Fix
- Removed `.env` from `pubspec.yaml` assets
- Implemented runtime config injection via `web/config.js`
- Added prevention checklist to `memory/CRITICAL_PROBLEMS.md`

### Prevention
- [ ] Never add `.env` to pubspec.yaml assets
- [ ] Verify: `find build/web -name "*.env*"` returns empty
- [ ] Test: `curl https://flowgroove.app/.env` returns 404

---

## 2. Firebase API Key Public Exposure (MEDIUM - ACCEPTED RISK)

**Date:** 2026-04-08
**Severity:** 🟡 MEDIUM
**Status:** ✅ ACCEPTED RISK (documented)

### The Problem
Firebase API key (`AIzaSyAxQzyEkKXjo3Ry2B9pcTMvcyk4d5o`) is committed in:
- `web/config.demo.js`
- `docs/app/config.js`

### Risk Assessment
Firebase API keys are NOT secrets — they are public project identifiers. Security is enforced by Firestore Security Rules, not by key obscurity.

### Mitigation
- ✅ Firestore rules restrict access to authenticated users
- ✅ Storage rules restrict access to resource owners
- ✅ No admin/privileged keys in client code
- ✅ Credentials for optional services (Spotify, Twitter) are empty

### Prevention
- [ ] Never store admin/service account keys in client code
- [ ] Regularly audit Firestore rules for over-permissive access
- [ ] Monitor Firebase usage for unexpected spikes

---

## 3. Editor Temp Files in Repository (LOW - RESOLVED)

**Date:** 2026-04-08
**Severity:** 🟢 LOW
**Status:** ✅ FIXED

### The Problem
Editor auto-save files (e.g., `.!15526!analytics_debug.dart`) appeared in `lib/utils/`.

### The Fix
- Deleted all temp files
- Added editor temp file patterns to `.gitignore`:
  - `.*!` (vim/emacs auto-save)
  - `!*~` (backup files)
  - `\#*\#` (emacs lock files)

---

## 4. Firestore Rules Temporary Relaxation (MEDIUM - RESOLVED)

**Date:** 2026-04-08
**Severity:** 🟡 MEDIUM
**Status:** ✅ RESOLVED

### The Problem
Setlist rules had comment: "TEMPORARILY RELAXED for data migration" suggesting unrestricted access.

### The Fix
- Confirmed rules still enforce owner-only access
- Removed misleading "TEMPORARILY RELAXED" comment
- Updated comment to reflect current production state

---

**Last Verified:** April 8, 2026
**Version:** 0.13.4+183
