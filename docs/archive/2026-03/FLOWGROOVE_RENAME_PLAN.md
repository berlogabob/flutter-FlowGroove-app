# 🔄 RepSync → FlowGroove - App Rename Plan

**Created:** March 10, 2026  
**Status:** In Progress  
**Priority:** URGENT

---

## 📋 OVERVIEW

Renaming the app from "RepSync" to "FlowGroove" throughout the entire project.

**GitHub Repo:** Already updated to `flutter-FlowGroove-app`  
**Package Name:** Will remain `com.example.flutter_repsync_app` (changing requires new app stores listing)

---

## 🎯 CATEGORIES OF CHANGES

### 1. **Critical - User-Facing** 🔴
- App name in Android/iOS
- App title in UI
- Public documentation
- Release notes

### 2. **High Priority - Code** 🟠
- Package references in imports
- Router deep links
- Service names
- Firebase references

### 3. **Medium Priority - Internal** 🟡
- Comments and documentation
- Variable names (where safe)
- Test file references
- Build configurations

### 4. **Low Priority - Metadata** 🟢
- Export files (.md exports from previous sessions)
- Old documentation
- Cached files

---

## 📊 STATISTICS

**Total Occurrences Found:** 2172

**Breakdown by File Type:**
- `.md` files: ~1800 (mostly documentation exports)
- `.dart` files: ~150 (code - HIGH PRIORITY)
- `.yaml` files: ~10 (configuration - HIGH PRIORITY)
- `.xml` files: ~5 (Android manifest - CRITICAL)
- `.js` files: ~20 (Firebase functions - HIGH PRIORITY)
- `.json` files: ~15 (configuration - MEDIUM PRIORITY)
- Other: ~200 (various configs, exports)

---

## ✅ COMPLETED ACTIONS

- [x] GitHub repository renamed to `flutter-FlowGroove-app`
- [x] README.md updated

---

## 🔄 IN PROGRESS

- [ ] Android app name
- [ ] iOS app name
- [ ] Dart code references
- [ ] Router deep links
- [ ] Firebase functions
- [ ] Documentation

---

## 📝 ACTION PLAN

### Phase 1: Critical User-Facing Changes (DONE FIRST)

#### 1.1 Android Manifest
**File:** `android/app/src/main/AndroidManifest.xml`
- Change `android:label="RepSync"` → `android:label="FlowGroove"`

#### 1.2 iOS Bundle Name
**File:** `ios/Runner/Info.plist`
- Change `CFBundleName` from `RepSync` → `FlowGroove`

#### 1.3 Main App Title
**File:** `lib/main.dart`
- Change `title: 'RepSync'` → `title: 'FlowGroove'`

#### 1.4 Router Deep Links
**File:** `lib/router/app_router.dart`
- Change `repSync://` → `flowgroove://`
- Change `https://repsync.app` → `https://flowgroove.app`

---

### Phase 2: Code References

#### 2.1 Package Imports
**Files:** All `.dart` files with `package:flutter_repsync_app`
- Keep as-is (package name unchanged for now)
- Note: Changing requires updating all deep links

#### 2.2 Comments & Documentation Strings
**Files:** All `.dart` files
- Replace "RepSync" → "FlowGroove" in comments
- Replace in doc strings

---

### Phase 3: Configuration Files

#### 3.1 Firebase Functions
**File:** `functions/index.js`
- Update bot name references
- Update welcome messages

#### 3.2 Pubspec
**File:** `pubspec.yaml`
- Keep `name: flutter_repsync_app` (changing breaks compatibility)
- Update `description` if mentions RepSync

---

### Phase 4: Documentation

#### 4.1 Master Documentation
**File:** `PROJECT_MASTER_DOCUMENTATION.md`
- Update title
- Update URLs
- Update all references

#### 4.2 README
**File:** `README.md`
- Already updated ✅

#### 4.3 Other Documentation
**Files:** All other `.md` files
- Update as needed
- Some can remain historical (marked as archived)

---

### Phase 5: Cleanup (Optional)

#### 5.1 Export Files
**Files:** `qwen-code-export-*.md`, `*_EXPORT.md`
- Can be deleted (historical artifacts)
- Or archived in `docs/archive/`

#### 5.2 Old Reports
**Files:** `*_REPORT.md`, `*_AUDIT.md`
- Archive or delete
- Keep only if historically valuable

---

## 🚀 EXECUTION ORDER

1. ✅ **Android Manifest** - App name
2. ✅ **iOS Info.plist** - App name  
3. ✅ **lib/main.dart** - App title
4. ✅ **lib/router/app_router.dart** - Deep links
5. ✅ **functions/index.js** - Bot messages
6. ✅ **PROJECT_MASTER_DOCUMENTATION.md** - Main docs
7. ⏳ **All other .dart files** - Comments
8. ⏳ **Configuration files** - As needed
9. ⏳ **Documentation** - Selective updates
10. ⏳ **Cleanup** - Archive old exports

---

## ⚠️ WARNINGS

### DO NOT CHANGE:
1. **Package name** (`flutter_repsync_app`) - Would break:
   - Existing app store listings
   - Firebase configuration
   - Deep links
   - Installed apps

2. **Firebase project ID** (`repsync-app-8685c`) - Would break:
   - All Firebase services
   - Authentication
   - Firestore database
   - Cloud Functions

3. **Android application ID** (`com.example.flutter_repsync_app`) - Would break:
   - Play Store listing
   - Existing user installations
   - Firebase Android app

### SAFE TO CHANGE:
1. **Display names** - User-facing text only
2. **Comments** - Internal documentation
3. **Deep link schemes** - If updated everywhere consistently
4. **Bot messages** - Telegram bot text

---

## 🧪 TESTING CHECKLIST

After renaming:

- [ ] Android app builds successfully
- [ ] iOS app builds successfully
- [ ] Web app builds successfully
- [ ] App name displays correctly on all platforms
- [ ] Deep links work (if changed)
- [ ] Firebase authentication works
- [ ] Telegram bot works
- [ ] No compilation errors
- [ ] No runtime errors

---

## 📊 PROGRESS TRACKING

| Category | Total | Changed | Remaining | % Complete |
|----------|-------|---------|-----------|------------|
| Critical (User-Facing) | 10 | 0 | 10 | 0% |
| High (Code) | 150 | 0 | 150 | 0% |
| Medium (Config) | 50 | 0 | 50 | 0% |
| Low (Docs) | 1800 | 0 | 1800 | 0% |
| **TOTAL** | **2010** | **0** | **2010** | **0%** |

---

## 🎯 SUCCESS CRITERIA

- ✅ All user-facing text shows "FlowGroove"
- ✅ All platforms build successfully
- ✅ No broken links or references
- ✅ Firebase still works
- ✅ Telegram bot updated
- ✅ Documentation consistent

---

**Last Updated:** March 10, 2026  
**Next Review:** After Phase 1 completion  
**Status:** 🔄 IN PROGRESS
