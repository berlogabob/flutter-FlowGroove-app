# 📦 PHASE 1 EXECUTION - Step by Step

**Started:** March 10, 2026  
**Status:** 🔄 IN PROGRESS  
**Current:** Step 1.1 - Riverpod Generator

---

## 🎯 PHASE 1 OVERVIEW

Three high-value upgrades with minimal disruption:
1. ✅ **Riverpod Generator** - Type-safe providers
2. ⏳ **Secure Storage** - Better auth security
3. ⏳ **Dio HTTP Client** - Better API handling

**Total Estimated Time:** ~13 hours  
**Risk Level:** Low

---

## 📝 STEP 1.1: RIVERPOD GENERATOR

### Goal
Migrate from manual provider definitions to `@riverpod` annotations for better type safety and less boilerplate.

### Packages to Add
```yaml
dependencies:
  riverpod_annotation: ^2.3.5

dev_dependencies:
  riverpod_generator: ^2.4.0
```

### Migration Plan

#### Step A: Add Dependencies
- [ ] Update `pubspec.yaml`
- [ ] Run `flutter pub get`

#### Step B: Migrate Providers
Files to migrate (in order):
1. `lib/providers/auth/error_provider.dart` (simplest)
2. `lib/providers/data/metronome_provider.dart`
3. `lib/providers/tuner_provider.dart`
4. `lib/providers/auth/auth_provider.dart` (most complex)
5. `lib/providers/data/data_providers.dart`

#### Step C: Generate Code
- [ ] Run `dart run build_runner build`
- [ ] Fix any compilation errors
- [ ] Test all features

#### Step D: Update Main App
- [ ] Update `lib/main.dart` to use generated providers
- [ ] Test app launch

### Testing Checklist
- [ ] App launches successfully
- [ ] Auth flow works (login/logout)
- [ ] Metronome works
- [ ] Tuner works
- [ ] Data providers work
- [ ] No runtime errors

---

## 📝 STEP 1.2: SECURE STORAGE

### Goal
Migrate auth token storage from `SharedPreferences` to `FlutterSecureStorage`.

### Packages to Add
```yaml
dependencies:
  flutter_secure_storage: ^9.2.0
```

### Migration Plan

#### Step A: Add Dependency
- [ ] Update `pubspec.yaml`
- [ ] Run `flutter pub get`

#### Step B: Platform Configuration
- [ ] **iOS:** Update `ios/Runner/Info.plist` with keychain entitlements
- [ ] **Android:** Update `android/app/build.gradle` for encrypted preferences

#### Step C: Create Secure Storage Service
- [ ] Create `lib/services/secure_storage_service.dart`
- [ ] Implement: `write`, `read`, `delete` methods

#### Step D: Update Auth Service
- [ ] Update `lib/services/auth_service.dart` (if exists)
- [ ] Or update `lib/providers/auth/auth_provider.dart`
- [ ] Replace `SharedPreferences` calls with secure storage

#### Step E: Test
- [ ] Login flow
- [ ] Logout flow
- [ ] Token persistence across app restarts
- [ ] Test on iOS, Android, Web

### Testing Checklist
- [ ] Login works on all platforms
- [ ] Token persists after app restart
- [ ] Logout clears token
- [ ] Web falls back to localStorage gracefully

---

## 📝 STEP 1.3: DIO HTTP CLIENT

### Goal
Replace `http` package with `dio` for better error handling and interceptors.

### Packages to Add
```yaml
dependencies:
  dio: ^5.7.0
  # Optional: talker_dio_logger: ^4.0.0
```

### Migration Plan

#### Step A: Add Dependency
- [ ] Update `pubspec.yaml`
- [ ] Run `flutter pub get`

#### Step B: Create Dio Instance
- [ ] Create `lib/services/api/dio_client.dart`
- [ ] Configure interceptors (logging, error handling)
- [ ] Set base options

#### Step C: Migrate API Services
Files to migrate (in order):
1. `lib/services/api/spotify_service.dart`
2. `lib/services/api/spotify_proxy_service.dart`
3. `lib/services/api/musicbrainz_service.dart`
4. `lib/services/api/track_analysis_service.dart`

#### Step D: Error Handling
- [ ] Create `lib/services/api/dio_exception_handler.dart`
- [ ] Map Dio errors to app errors
- [ ] Update error displays

#### Step E: Test
- [ ] Spotify search works
- [ ] MusicBrainz search works
- [ ] Error handling works
- [ ] Offline mode still works

### Testing Checklist
- [ ] All API calls work
- [ ] Errors display correctly
- [ ] Timeouts handled properly
- [ ] Interceptors log correctly

---

## 📊 PROGRESS TRACKING

| Step | Status | Started | Completed | Notes |
|------|--------|---------|-----------|-------|
| 1.1 - Riverpod Generator | ⏳ TODO | - | - | - |
| 1.2 - Secure Storage | ⏳ TODO | - | - | - |
| 1.3 - Dio Client | ⏳ TODO | - | - | - |

---

## 🎯 SUCCESS CRITERIA

Phase 1 is complete when:
- ✅ All providers use `@riverpod` annotation
- ✅ Auth tokens stored securely
- ✅ All API calls use Dio
- ✅ All tests pass
- ✅ All platforms build successfully
- ✅ No regressions in functionality

---

## ⚠️ ROLLBACK PLAN

If something goes wrong:

1. **Git Backup:**
   ```bash
   git checkout -b backup-before-phase1
   ```

2. **Revert:**
   ```bash
   git revert HEAD~n  # where n is number of commits
   ```

3. **Restore Dependencies:**
   - Revert `pubspec.yaml` changes
   - Run `flutter pub get`

---

## 📚 RESOURCES

- [Riverpod Generator Docs](https://riverpod.dev/docs/introduction/getting_started_hello_world)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [Dio](https://pub.dev/packages/dio)

---

**Next Action:** Start Step 1.1 - Riverpod Generator  
**Estimated Time:** 4-6 hours  
**Risk Level:** Low
