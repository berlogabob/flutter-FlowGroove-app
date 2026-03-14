# 📦 DEPENDENCY ISSUES

**Purpose:** Document dependency conflicts and solutions

**Rule:** Review before updating ANY dependency

---

## 1. Android Deprecation Warnings

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
- Old dependency versions
- SDK version outdated (`^3.10.7`)
- Packages using deprecated Android APIs

### Updated Packages
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

### Impact
- Build warnings (non-fatal)
- Potential future compatibility issues
- Code quality concerns

### Prevention
- ✅ Run `flutter pub outdated` regularly
- ✅ Update SDK with major Flutter releases
- ✅ Test after dependency updates
- ✅ Review changelogs for breaking changes

### Verification Commands
```bash
# Check for outdated packages
flutter pub outdated

# Check for newer versions
flutter pub outdated --major-versions

# Update specific package
flutter pub add package_name:^version

# Update all packages
flutter pub get
```

### Last Verified
2026-03-14 ✅

---

## 2. Package Version Conflicts

**Date:** 2026-03-14  
**Severity:** 🟡 **MEDIUM**  
**Status:** ⚠️ MONITORING  
**Category:** dependencies, build

### The Problem
```
Because flutter_repsync_app depends on package ^version which doesn't match any versions, version solving failed.
```

### Common Conflicts
- `flutter_riverpod ^3.3.2` - Version doesn't exist
- `firebase_core ^4.5.1` - Version doesn't exist

### Root Cause
- Specified version not yet released
- Typo in version number
- Version constraints too strict

### The Fix
Use available versions:
```yaml
dependencies:
  flutter_riverpod: ^3.3.1  # Not ^3.3.2
  firebase_core: ^4.5.0     # Not ^4.5.1
```

### Prevention
- ✅ Check pub.dev for available versions
- ✅ Use `^` for compatible versions
- ✅ Avoid exact versions unless necessary
- ✅ Test version updates before committing

### Verification
```bash
# Check if version exists
flutter pub pubspec_parse "package:^version"

# View available versions
flutter pub pubspec_parse package_name
```

### Last Verified
2026-03-14

---

## 3. Wasm Compatibility Warnings

**Date:** 2026-03-14  
**Severity:** 🟢 **LOW**  
**Status:** ⚠️ MONITORING  
**Category:** web, wasm, dependencies

### The Problem
```
Wasm dry run findings:
Found incompatibilities with WebAssembly.

package:flutter_secure_storage_web/... - dart:html unsupported
package:image/... - avoid_double_and_int_checks lint violation
```

### Root Cause
- Some packages not yet Wasm-compatible
- `dart:html` not supported in Wasm
- Lint violations in dependencies

### Impact
- Wasm build warnings (non-fatal)
- Future Wasm builds may fail
- Performance optimization limited

### Current Status
- Wasm builds still work with warnings
- Using `--no-wasm-dry-run` suppresses warnings
- Not critical for current deployment

### Prevention
- ✅ Monitor package updates for Wasm support
- ✅ Consider alternative packages if Wasm critical
- ✅ Use `--no-wasm-dry-run` for now

### Verification
```bash
# Build with Wasm check
flutter build web

# Build without Wasm warnings
flutter build web --no-wasm-dry-run
```

### Last Verified
2026-03-14

---

## Dependency Update Checklist

### Before Updating:
- [ ] Read DEPENDENCY_ISSUES.md
- [ ] Check current versions in pubspec.yaml
- [ ] Run `flutter pub outdated`
- [ ] Review package changelogs
- [ ] Check for breaking changes

### During Update:
- [ ] Update one package at a time
- [ ] Run `flutter pub get`
- [ ] Check for conflicts
- [ ] Resolve version mismatches

### After Update:
- [ ] Run `flutter clean`
- [ ] Build for all platforms
- [ ] Test thoroughly
- [ ] Check for new warnings
- [ ] Verify no regressions

---

## Version Management Rules

### Rule #1: Use Caret (^) Versions
```yaml
# ✅ GOOD - Allows compatible updates
firebase_core: ^4.5.0

# ❌ BAD - Too strict
firebase_core: 4.5.0

# ❌ BAD - Too loose
firebase_core: any
```

### Rule #2: Check Before Updating
```bash
# Always check what's available
flutter pub outdated

# Review before committing
flutter pub upgrade --dry-run
```

### Rule #3: Test After Updates
```bash
# Clean build
flutter clean
flutter pub get

# Build all platforms
flutter build web
flutter build apk
```

### Rule #4: Document Issues
- Add to this file when dependency causes problems
- Include before/after versions
- Note any special configuration needed

---

## Known Compatible Versions (As of 2026-03-14)

```yaml
environment:
  sdk: ^3.11.1

dependencies:
  # Firebase
  cloud_firestore: ^6.1.3
  firebase_auth: ^6.2.0
  firebase_core: ^4.5.0
  
  # State Management
  flutter_riverpod: ^3.3.1
  
  # Audio
  audioplayers: ^6.6.0
  flutter_sound: ^9.30.0
  
  # UI
  go_router: ^17.1.0
  cupertino_icons: ^1.0.8
  
  # Utilities
  http: ^1.4.0
  intl: ^0.20.2
  url_launcher: ^6.3.2
  uuid: ^4.5.3
  
  # Build
  build_runner: ^2.12.2
  json_serializable: ^6.13.0
```

---

**Maintained By:** Mr. Memory (`mr-memory.md`)  
**Last Review:** 2026-03-14  
**Next Review:** Before next dependency update
