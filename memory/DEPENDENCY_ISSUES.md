# 📦 DEPENDENCY ISSUES

**Purpose:** Track dependency conflicts, upgrades, and solutions
**Last Updated:** April 24, 2026
**Version:** 0.13.4+183

---

## 1. Flutter Sound v10 Breaking Changes (MONITORING)

**Date:** 2026-04-01
**Severity:** 🟡 MEDIUM
**Status:** ⚠️ MONITORING

### The Issue
`flutter_sound` v10 has breaking API changes. Project is pinned to v9.30.0 for stability.

### Current State
```yaml
flutter_sound: ^9.30.0  # Keep v9 for stability
```

### Action Required
- [ ] Test v10 upgrade before updating
- [ ] Review v10 changelog for breaking changes
- [ ] Update metronome audio engine accordingly

---

## 2. Riverpod v3 Migration (RESOLVED)

**Date:** 2026-04-01
**Severity:** 🟡 MEDIUM
**Status:** ✅ RESOLVED

### The Issue
Riverpod updated from v2 to v3 with API changes.

### Current State
```yaml
flutter_riverpod: ^3.3.1
riverpod_annotation: ^4.0.2
riverpod_generator: ^4.0.3
```

### Resolution
- All providers updated to v3 API
- `riverpod_lint.yaml` configured
- Code generation updated

---

## 3. Firebase Package Updates (MONITORING)

**Date:** 2026-04-08
**Severity:** 🟢 LOW
**Status:** ⚠️ MONITORING

### Current Versions
```yaml
firebase_core: ^4.5.0
firebase_auth: ^6.2.0
cloud_firestore: ^6.1.3
firebase_analytics: ^12.1.3
firebase_storage: ^13.1.0
```

### Notes
- Firebase packages are on latest stable
- Flutter 3.11.1 SDK compatibility verified
- `firebase_options.dart` uses platform-specific config

### Prevention
- [ ] Test Firebase init after major Flutter updates
- [ ] Verify `firebase_options.dart` matches Firebase Console
- [ ] Check Firestore rules after auth changes

---

## 4. Hive Offline Storage (CONSIDERING MIGRATION)

**Date:** 2026-04-08
**Severity:** 🟢 LOW
**Status:** ⚠️ MONITORING

### Current State
```yaml
hive: ^2.2.3
hive_flutter: ^1.1.0
```

### Notes
- Hive is stable but no longer actively developed
- Isar is the recommended successor (same author)
- Migration would require rewriting all offline caching logic
- Not urgent — Hive works fine for current use case

### Future Consideration
- [ ] Evaluate Isar migration for new features
- [ ] Benchmark performance improvement
- [ ] Plan migration if Hive becomes incompatible with Flutter

---

## 5. `withOpacity` Deprecation → `withValues` (RESOLVED)

**Date:** 2026-04-01
**Severity:** 🟢 LOW
**Status:** ✅ FIXED

### The Issue
Flutter deprecated `Color.withOpacity()` in favor of `Color.withValues()`.

### The Fix
- All 60+ instances replaced with `withValues(alpha: X)`
- No remaining `withOpacity` calls in codebase

### Prevention
- [ ] Run `flutter analyze` after Flutter SDK updates
- [ ] Watch for deprecation warnings in CI

---

## 6. `functions/` Install Baseline vs. Vulnerability Debt (MONITORING)

**Date:** 2026-04-24
**Severity:** 🟡 MEDIUM
**Status:** ⚠️ MONITORING

### Current State
- `npm ci` works in `functions/` when using a clean npm cache
- `npm ls --depth=0` resolves correctly after install
- direct `functions/` dependencies are now:
  - `firebase-admin@13.8.0`
  - `firebase-functions@7.2.5`
  - `telegraf@4.16.3`
- safe transitive overrides are pinned for:
  - `brace-expansion`
  - `fast-xml-parser`
  - `path-to-regexp`
  - `protobufjs`
- local default `~/.npm` cache on this machine may be broken due to ownership/history issues
- `npm audit --omit=dev` now reports 11 production vulnerabilities:
  - 2 low
  - 9 moderate
  - 0 high
  - 0 critical

### Durable Rule
- Separate install reproducibility problems from dependency vulnerability problems
- Use a clean cache or CI environment before concluding that `functions/` is broken
- Treat remaining Firebase Admin / Google GAX / storage transitive issues as open supply-chain debt until upstream dependency trees move further

---

## SDK & Flutter Version

```yaml
environment:
  sdk: ^3.11.1
```

**Flutter Channel:** Stable
**Last SDK Update:** April 2026

---

**Last Verified:** April 8, 2026
**Version:** 0.13.4+183
