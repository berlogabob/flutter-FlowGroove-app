# Dependency Update - February 20, 2026

## Overview

This document records the dependency updates made to fix warnings from `flutter pub outdated`.

## Updated Packages

### Direct Dependencies

| Package | Previous Version | New Version | Change Type |
|---------|-----------------|-------------|-------------|
| `flutter_dotenv` | 5.2.1 | 6.0.0 | Major |
| `package_info_plus` | 8.3.1 | 9.0.0 | Major |

### Transitive Dependencies (Auto-Updated)

| Package | Previous Version | New Version |
|---------|-----------------|-------------|
| `_fe_analyzer_shared` | 93.0.0 | 95.0.0 (available) |
| `analyzer` | 10.0.1 | 10.1.0 (available) |
| `image` | 4.5.4 | 4.8.0 (available) |
| `meta` | 1.17.0 | 1.18.1 (available) |
| `shelf_web_socket` | 2.0.1 | 3.0.0 (available) |
| `json_annotation` | 4.10.0 | 4.11.0 (available) |

## Breaking Changes Analysis

### flutter_dotenv 5.x → 6.0.0

**Breaking Changes:**

1. **Method Rename: `testLoad` → `loadFromString`**
   - The `testLoad` method has been renamed to `loadFromString` to better reflect its use outside test environments.
   - **Action Required:** If the codebase uses `dotenv.testLoad()`, it must be updated to `dotenv.loadFromString()`.

2. **Behavior Change: Empty File Handling**
   - Previously: Empty env files with `isOptional = true` would throw an error.
   - Now: Returns an empty env without throwing.
   - **Impact:** This is a non-breaking improvement that makes the library more forgiving.

3. **SDK Range Change**
   - Dropped support for pre-release SDK `2.12.0-0`.
   - Now supports `2.12.0` onwards.
   - **Impact:** No impact - project uses SDK `^3.10.7`.

### package_info_plus 8.x → 9.0.0

**Breaking Changes:**

1. **Android Build Requirements Updated** (#3674)
   - Android Gradle Plugin >= 8.12.1
   - Gradle wrapper >= 8.13
   - Kotlin 2.2.0
   - **Impact:** May require updates to Android build configuration files if building for Android.

## Test Results

### Flutter Analyze

```bash
flutter analyze lib/
```

**Result:** 126 issues found (all pre-existing)
- 0 errors related to dependency updates
- 2 warnings (pre-existing null comparison and dead code)
- 124 info-level warnings (mostly `avoid_print` for debug code)

**Conclusion:** No breaking changes detected in the codebase from the dependency updates.

### Package Resolution

```bash
flutter pub get
```

**Result:** Successfully resolved and updated 2 dependencies.

## Files Modified

- `/pubspec.yaml` - Updated `flutter_dotenv` and `package_info_plus` versions

## Recommendations

1. **For flutter_dotenv:** Search the codebase for any usage of `testLoad()` method and update to `loadFromString()` if found.

2. **For package_info_plus:** When building for Android, ensure the Android Gradle configuration meets the new minimum requirements:
   - Update `android/build.gradle` if needed
   - Update `android/gradle/wrapper/gradle-wrapper.properties` if needed

## Verification Commands

```bash
# Check for outdated packages
flutter pub outdated

# Verify no analysis errors
flutter analyze lib/

# Run tests (if available)
flutter test
```

## Date

February 20, 2026
