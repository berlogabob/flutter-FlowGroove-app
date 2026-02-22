# SPRINT PLAN - FULL PROJECT REVISION
**Flutter RepSync App - Complete Audit Remediation**

---

**Date:** 2026-02-22  
**Version Target:** 0.10.1+1  
**Total Sprints:** 18  
**Duration:** 5-7 days  
**Agents:** 12 (10 existing + 2 new)  
**Mode:** FULLY AUTONOMOUS EXECUTION  

---

## NEW AGENTS CREATED

| Agent | Role | Responsibilities |
|-------|------|------------------|
| **MrAndroid** | Mobile Debug Specialist | Collect Android telemetry, debug info, crash logs, performance metrics |
| **MrRelease** | Release Manager | Coordinate releases, versioning, CHANGELOG, deployment |

---

## SPRINT BREAKDOWN

### WAVE 1: CRITICAL FIXES (Day 1-2)

#### SPRINT 1: Fix Compilation Errors (30 min)
**Agent:** MrSeniorDeveloper  
**Support:** MrCleaner  
**Issues:** 10 errors in metronome_preset.dart, scripts/fix_all_bands.dart

**Tasks:**
1. Remove `const` from `defaults` list (lines 84-108) - DateTime is not const
2. Create `band_data_fixer.dart` or remove script
3. Verify with `flutter analyze`

**Acceptance:**
- ✅ 0 compilation errors
- ✅ `flutter analyze` passes

---

#### SPRINT 2: Remove Unused Code (30 min)
**Agent:** MrCleaner  
**Support:** MrRepetitive  
**Issues:** 13 warnings (unused imports, variables, dead code)

**Tasks:**
1. Remove unused imports (5 files)
2. Remove unused variables (4 test files)
3. Remove dead code (metronome_widget.dart line 63, 274)
4. Remove unused `_getMeasureCount()` method

**Acceptance:**
- ✅ 0 warnings
- ✅ `dart format lib/` passes

---

#### SPRINT 3: Fix Failing Tests (90 min)
**Agent:** MrTester  
**Support:** MrSeniorDeveloper  
**Issues:** 122 failing tests (23.4% failure rate)

**Tasks:**
1. Fix mockito setup in auth_integration_test.dart (19 failing)
2. Fix mockito setup in api_integration_test.dart (5 failing)
3. Fix Material widget setup in test_helpers.dart (6 failing)
4. Fix widget finder issues (error_banner, confirmation_dialog)
5. Fix null cast patterns in register_screen_test.dart

**Acceptance:**
- ✅ 521/521 tests passing
- ✅ 100% success rate

---

### WAVE 2: ARCHITECTURE FIXES (Day 2-3)

#### SPRINT 4: Migrate MetronomeService to Riverpod (60 min)
**Agent:** MrSeniorDeveloper  
**Support:** SystemArchitect  
**Issue:** Inconsistent state management (ChangeNotifier instead of Riverpod)

**Tasks:**
1. Create MetronomeNotifier class
2. Create MetronomeState class
3. Create NotifierProvider
4. Update all consumers
5. Remove old singleton pattern

**Acceptance:**
- ✅ Riverpod pattern used consistently
- ✅ All metronome features working

---

#### SPRINT 5: Extract FirestoreService (45 min)
**Agent:** MrSeniorDeveloper  
**Support:** SystemArchitect  
**Issue:** God file (data_providers.dart - 294 lines)

**Tasks:**
1. Create `/lib/services/firestore_service.dart`
2. Move FirestoreService class from data_providers.dart
3. Update imports in all files
4. Verify all CRUD operations work

**Acceptance:**
- ✅ Service properly separated
- ✅ All data operations working

---

#### SPRINT 6: Implement Mobile Audio Engine (60 min)
**Agent:** MrSeniorDeveloper  
**Support:** MrAndroid  
**Issue:** Empty stub in audio_engine_mobile.dart

**Tasks:**
1. Add audioplayers to pubspec.yaml
2. Implement AudioEngine for mobile using audioplayers
3. Generate click sounds programmatically or use assets
4. Test on connected Android device
5. Collect debug telemetry

**Acceptance:**
- ✅ Audio plays on Android
- ✅ No crashes or errors
- ✅ Debug logs collected

---

#### SPRINT 7: Implement Error Handling Strategy (90 min)
**Agent:** SystemArchitect  
**Support:** MrSeniorDeveloper  
**Issue:** Silent failures in services

**Tasks:**
1. Create ApiError model
2. Create ErrorProvider with Riverpod
3. Standardize error types (NetworkError, AuthError, ValidationError)
4. Update all services to throw typed errors
5. Add error boundaries in UI

**Acceptance:**
- ✅ All errors properly typed
- ✅ UI shows user-friendly messages
- ✅ Errors logged properly

---

### WAVE 3: OFFLINE-FIRST & REFACTORING (Day 3-4)

#### SPRINT 8: Add Local Caching Layer (120 min)
**Agent:** SystemArchitect  
**Support:** MrSeniorDeveloper  
**Issue:** No offline-first design

**Tasks:**
1. Add Hive to pubspec.yaml
2. Create CacheService
3. Create cache models (Song, Band, Setlist)
4. Implement sync strategy (cache-first, then network)
5. Add offline indicator UI

**Acceptance:**
- ✅ App works offline
- ✅ Data syncs when online
- ✅ Offline indicator visible

---

#### SPRINT 9: Refactor Large Files - Part 1 (90 min)
**Agent:** MrSeniorDeveloper  
**Support:** MrRepetitive  
**Issues:** metronome_widget.dart (458 lines)

**Tasks:**
1. Extract BPM controls widget
2. Extract TimeSignature controls widget
3. Extract AccentPattern editor widget
4. Extract Frequency controls widget (advanced)
5. Update parent widget

**Acceptance:**
- ✅ metronome_widget.dart <200 lines
- ✅ All widgets reusable
- ✅ Tests passing

---

#### SPRINT 10: Refactor Large Files - Part 2 (90 min)
**Agent:** MrSeniorDeveloper  
**Support:** MrRepetitive  
**Issues:** add_song_screen.dart (494 lines), songs_list_screen.dart (409 lines)

**Tasks:**
1. Extract song form to separate widget
2. Extract Spotify search section
3. Extract filtering logic to provider
4. Create SongQuery model
5. Update screen to use provider

**Acceptance:**
- ✅ add_song_screen.dart <300 lines
- ✅ songs_list_screen.dart <300 lines
- ✅ Filtering in provider

---

### WAVE 4: TESTING & UX (Day 4-5)

#### SPRINT 11: Add Service Layer Tests (180 min)
**Agent:** MrTester  
**Support:** MrAndroid  
**Issue:** 344 lines of services with 0% coverage

**Tasks:**
1. Test spotify_service.dart (85 lines)
2. Test musicbrainz_service.dart (47 lines)
3. Test track_analysis_service.dart (27 lines)
4. Test metronome_service.dart (80 lines)
5. Test pdf_service.dart
6. Test audio_engine.dart

**Acceptance:**
- ✅ All services tested
- ✅ Coverage ≥80% for services
- ✅ Mock external APIs properly

---

#### SPRINT 12: Implement UX P0 Fixes (60 min)
**Agent:** MrUXUIDesigner  
**Support:** MrStupidUser  
**Issues:** UX-001, UX-002, UX-003, UX-006

**Tasks:**
1. Add "Forgot Password?" link to login screen
2. Show password requirements before submission
3. Add PDF export button to setlist cards
4. Show invite code immediately after band creation
5. Add "Invite Members" CTA

**Acceptance:**
- ✅ All P0 UX issues fixed
- ✅ MrStupidUser approves
- ✅ No regressions

---

#### SPRINT 13: Simplify Metronome UI (60 min)
**Agent:** MrUXUIDesigner  
**Support:** CreativeDirector  
**Issue:** Technical overload (Hz, wave types overwhelm users)

**Tasks:**
1. Hide frequency inputs behind "Advanced Settings" collapsible
2. Replace "A/B" text input with visual toggle buttons
3. Replace dropdowns with preset buttons (4/4, 3/4, 6/8)
4. Add help tooltips for BPM/Key
5. Rename "Sound" to "Tone" with descriptions

**Acceptance:**
- ✅ UI simplified for casual users
- ✅ Advanced options still accessible
- ✅ Creative Director approves

---

### WAVE 5: INFRASTRUCTURE (Day 5-6)

#### SPRINT 14: Implement go_router Navigation (120 min)
**Agent:** MrSeniorDeveloper  
**Support:** SystemArchitect  
**Issue:** Direct Navigator.pushNamed coupling

**Tasks:**
1. Add go_router to pubspec.yaml
2. Create router configuration
3. Define all routes with type-safe paths
4. Replace all Navigator.pushNamed calls
5. Add deep linking support

**Acceptance:**
- ✅ All navigation via go_router
- ✅ Type-safe routes
- ✅ Deep linking works

---

#### SPRINT 15: Add json_serializable (60 min)
**Agent:** MrRepetitive  
**Support:** MrCleaner  
**Issue:** Manual toJson/fromJson boilerplate

**Tasks:**
1. Add json_serializable, build_runner to pubspec.yaml
2. Add @JsonSerializable() to all models
3. Run build_runner
4. Remove manual toJson/fromJson
5. Update tests if needed

**Acceptance:**
- ✅ All models use json_serializable
- ✅ build_runner generates correctly
- ✅ Tests passing

---

#### SPRINT 16: Reorganize Directories (90 min)
**Agent:** MrCleaner  
**Support:** MrRepetitive  
**Issue:** Flat directory structure

**Tasks:**
1. Reorganize /lib/providers/ into auth/, data/, ui/
2. Reorganize /lib/services/ into api/, audio/, export/
3. Update all imports
4. Verify compilation
5. Update documentation

**Acceptance:**
- ✅ Logical directory structure
- ✅ All imports updated
- ✅ Compilation successful

---

### WAVE 6: FINALIZATION (Day 6-7)

#### SPRINT 17: Reach 80% Test Coverage (180 min)
**Agent:** MrTester  
**Support:** All agents  
**Issue:** 39.8% coverage (target: 80%)

**Tasks:**
1. Add missing model tests
2. Add missing widget tests
3. Add missing screen tests
4. Add integration tests (4 critical flows)
5. Generate coverage report

**Acceptance:**
- ✅ Coverage ≥80%
- ✅ All critical paths tested
- ✅ Integration tests passing

---

#### SPRINT 18: Final QA & Release (120 min)
**Agent:** MrRelease  
**Support:** All agents  
**Goal:** Release v0.10.1+1

**Tasks:**
1. Run full test suite
2. Run flutter analyze
3. Build web and Android
4. Test on Android device (MrAndroid)
5. Update README, CHANGELOG
6. Create release notes
7. Tag release v0.10.1+1

**Acceptance:**
- ✅ All quality gates passed
- ✅ Release deployed
- ✅ Documentation updated

---

## AGENT ASSIGNMENTS

| Agent | Primary Sprints | Support Sprints |
|-------|----------------|-----------------|
| **MrSeniorDeveloper** | 1, 4, 5, 6, 9, 10, 14 | 3, 7, 8 |
| **MrCleaner** | 2, 15, 16 | 1, 10 |
| **MrTester** | 3, 11, 17 | - |
| **MrArchitector** | 7, 8 | 4, 5, 14 |
| **MrUXUIDesigner** | 12, 13 | - |
| **MrStupidUser** | 12 | - |
| **CreativeDirector** | 13 | - |
| **MrRepetitive** | 15, 16 | 2, 9, 10 |
| **MrPlanner** | - | All (tracking) |
| **MrSync** | All (coordination) | - |
| **MrLogger** | All (logging) | - |
| **MrAndroid** | 6, 11, 18 | - |
| **MrRelease** | 18 | - |

---

## QUALITY GATES

### Gate 1 (After Sprint 3)
- [ ] 0 compilation errors
- [ ] 0 warnings
- [ ] 521/521 tests passing

### Gate 2 (After Sprint 7)
- [ ] Riverpod used consistently
- [ ] FirestoreService extracted
- [ ] Error handling implemented
- [ ] Mobile audio working

### Gate 3 (After Sprint 10)
- [ ] Local caching working
- [ ] Large files refactored
- [ ] Offline-first functional

### Gate 4 (After Sprint 13)
- [ ] Service tests complete
- [ ] UX P0 fixes implemented
- [ ] Metronome UI simplified

### Gate 5 (After Sprint 16)
- [ ] go_router implemented
- [ ] json_serializable added
- [ ] Directories reorganized

### Gate 6 (After Sprint 18)
- [ ] Coverage ≥80%
- [ ] All quality gates passed
- [ ] Release v0.10.1+1 deployed

---

## ANDROID DEBUG TELEMETRY

### MrAndroid Responsibilities
1. **During each sprint:**
   - Collect `flutter logs` continuously
   - Monitor for crashes, exceptions
   - Track performance metrics (frame times, memory)
   - Capture ANR (App Not Responding) events

2. **Commands:**
   ```bash
   # Continuous log collection
   flutter logs --device <device_id> > /tmp/android_logs.txt
   
   # Performance metrics
   flutter run --profile --device <device_id>
   
   # Memory tracking
   flutter pub global activate devtools
   flutter pub global run devtools --appSize
   
   # Screenshot on errors
   flutter screenshot --device <device_id>
   ```

3. **Report format:**
   ```markdown
   ## Android Telemetry - Sprint X
   ### Device Info
   - Model: [device]
   - Android Version: [version]
   - App Version: 0.10.0+1
   
   ### Issues Found
   | Timestamp | Type | Message |
   |-----------|------|---------|
   
   ### Performance
   | Metric | Value | Target |
   |--------|-------|--------|
   | Frame Time | X ms | <16ms |
   | Memory | X MB | <100MB |
   ```

---

## EXECUTION MODE

**FULLY AUTONOMOUS** - All sprints execute without user approval.  
**PARALLEL WHERE POSSIBLE** - Multiple agents work simultaneously.  
**CONTINUOUS LOGGING** - MrLogger tracks all progress.  
**SCOPE ENFORCEMENT** - MrSync prevents scope creep.  

---

**Status:** READY TO EXECUTE  
**Next:** Begin Sprint 1 immediately
