# Full Project Revision Plan

**Date:** 2026-02-22
**Version:** 0.10.0+1
**Prepared by:** MrPlanner
**Status:** Ready for Execution

---

## Current State

### Project Overview
| Parameter | Value |
|-----------|-------|
| **Project Name** | RepSync (Flutter RepSync App) |
| **Version** | 0.10.0+1 |
| **Target Platforms** | Web (primary), Android, iOS |
| **Framework** | Flutter 3.41.1 (Dart 3.11.0) |
| **State Management** | Provider (ChangeNotifier) |
| **Backend** | Firebase (Auth + Firestore) |
| **Active Branch** | `dev03-autonomous-dev-day2` |
| **Stable Branch** | `dev02` |

### Current Feature Status
| Feature | Status | Completion |
|---------|--------|------------|
| Authentication (Email, Google) | ✅ Complete | 100% |
| Band Management | ✅ Complete | 100% |
| Song Database | ✅ Complete | 100% |
| Setlists + PDF Export | ✅ Complete | 100% |
| Metronome (Core) | ✅ Complete | 100% |
| Metronome (Subdivisions) | ✅ Complete | 100% |
| Metronome (Tap BPM) | ✅ Complete | 100% |
| Metronome (Presets) | ✅ Complete | 100% |
| Metronome (Song Integration) | ⏳ Partial | 70% |
| Mobile Audio | ❌ Not Implemented | 0% |

### Code Quality Metrics
| Metric | Count | Target | Status |
|--------|-------|--------|--------|
| **Compilation Errors** | 8 | 0 | 🔴 Critical |
| **Warnings** | 5 | 0 | 🟠 High |
| **Info-level Issues** | 26 | <10 | 🟡 Medium |
| **Total Issues** | 39 | 0 | 🔴 Action Required |

### Agent Infrastructure
**10 Registered Agents:**
1. MrPlanner - Task prioritization
2. SystemArchitect - Architecture design
3. MrSeniorDeveloper - Code implementation
4. UXAgent - UI/UX design
5. MrCleaner - Code quality
6. MrLogger - Session logging
7. MrStupidUser - User testing
8. MrRepetitive - Automation
9. MrTester - QA/Testing
10. CreativeDirector - User journey

---

## Revision Areas

| Area | Scope | Priority | Time Estimate |
|------|-------|----------|---------------|
| **1. Critical Bug Fixes** | Fix 8 compilation errors in `metronome_preset.dart` | 🔴 Critical | 30 min |
| **2. Code Quality** | Fix 5 warnings + 26 info-level issues | 🟠 High | 45 min |
| **3. Mobile Audio** | Implement `audioplayers` for Android/iOS | 🟠 High | 60 min |
| **4. Song Integration** | Connect SongBPMBadge to actual song data | 🟡 Medium | 30 min |
| **5. Presets UI** | Build save/load preset dialog | 🟡 Medium | 30 min |
| **6. Test Coverage** | Write unit tests for metronome features | 🟡 Medium | 45 min |
| **7. Documentation** | Update README, create CHANGELOG | 🟢 Low | 30 min |
| **8. Responsive Design** | Verify tablet/desktop layouts | 🟢 Low | 30 min |

**Total Estimated Time:** 4 hours 30 minutes

---

## Task Schedule

### Phase 1: Critical Fixes (Day 1 - Morning)

| Time | Task | Agent | Status | Dependencies |
|------|------|-------|--------|--------------|
| 0:00-0:30 | Fix `metronome_preset.dart` const errors | MrSeniorDeveloper | ⬜ Pending | None |
| 0:30-1:00 | Fix unused imports and dead code | MrCleaner | ⬜ Pending | None |
| 1:00-1:15 | Code review + merge | MrSeniorDeveloper | ⬜ Pending | Previous tasks |
| 1:15-1:30 | Run `flutter analyze` + verify 0 errors | MrCleaner | ⬜ Pending | All fixes |

**Quality Gate 1:** `flutter analyze` returns 0 errors, 0 warnings

### Phase 2: Code Quality (Day 1 - Midday)

| Time | Task | Agent | Status | Dependencies |
|------|------|-------|--------|--------------|
| 1:30-2:00 | Fix 26 info-level issues (const optimizations) | MrCleaner | ⬜ Pending | Phase 1 |
| 2:00-2:15 | Run `dart format` on all files | MrCleaner | ⬜ Pending | Previous |
| 2:15-2:30 | Verify formatting + commit | MrLogger | ⬜ Pending | All fixes |

**Quality Gate 2:** Code formatted, all info-level issues resolved or documented

### Phase 3: Mobile Audio (Day 1 - Afternoon)

| Time | Task | Agent | Status | Dependencies |
|------|------|-------|--------|--------------|
| 2:30-3:00 | Review `audio_engine_mobile.dart` stub | SystemArchitect | ⬜ Pending | None |
| 3:00-3:30 | Implement `audioplayers` integration | MrSeniorDeveloper | ⬜ Pending | Architecture review |
| 3:30-4:00 | Test audio on Android emulator | MrTester | ⬜ Pending | Implementation |
| 4:00-4:15 | Document mobile audio setup | MrLogger | ⬜ Pending | Testing |

**Quality Gate 3:** Metronome produces sound on Android device/emulator

### Phase 4: Feature Completion (Day 2 - Morning)

| Time | Task | Agent | Status | Dependencies |
|------|------|-------|--------|--------------|
| 0:00-0:30 | Connect SongBPMBadge to song model | MrSeniorDeveloper | ⬜ Pending | None |
| 0:30-1:00 | Build preset save/load dialog UI | UXAgent | ⬜ Pending | None |
| 1:00-1:30 | Implement preset persistence (local storage) | MrSeniorDeveloper | ⬜ Pending | UI complete |
| 1:30-1:45 | User testing: song integration + presets | MrStupidUser | ⬜ Pending | Implementation |

**Quality Gate 4:** Song BPM badge functional, presets can be saved/loaded

### Phase 5: Testing (Day 2 - Afternoon)

| Time | Task | Agent | Status | Dependencies |
|------|------|-------|--------|--------------|
| 1:45-2:30 | Write unit tests for MetronomeService | MrTester | ⬜ Pending | Phase 1-4 |
| 2:30-3:00 | Write widget tests for MetronomeWidget | MrTester | ⬜ Pending | Phase 1-4 |
| 3:00-3:30 | Write integration test (tap BPM flow) | MrTester | ⬜ Pending | All features |
| 3:30-4:00 | Run test coverage report | MrLogger | ⬜ Pending | All tests |

**Quality Gate 5:** Test coverage ≥80% for metronome components

### Phase 6: Documentation (Day 2 - Late Afternoon)

| Time | Task | Agent | Status | Dependencies |
|------|------|-------|--------|--------------|
| 4:00-4:15 | Update README with metronome features | MrLogger | ⬜ Pending | All features |
| 4:15-4:30 | Create CHANGELOG.md | MrLogger | ⬜ Pending | All features |
| 4:30-4:45 | Update ToDo.md with revision status | MrSync | ⬜ Pending | All tasks |
| 4:45-5:00 | Final review + release prep | MrPlanner | ⬜ Pending | All phases |

**Quality Gate 6:** All documentation updated, release notes ready

---

## Parallel Execution Groups

### Group A: Code Quality (Can run parallel with Group B)
- **Agents:** MrCleaner, MrSeniorDeveloper
- **Tasks:** Phase 1 (Critical Fixes), Phase 2 (Code Quality)
- **Duration:** 1.5 hours
- **Coordination:** MrSync

### Group B: Architecture Review (Can run parallel with Group A)
- **Agents:** SystemArchitect, MrSeniorDeveloper
- **Tasks:** Phase 3 prep (Mobile Audio architecture)
- **Duration:** 30 min
- **Coordination:** MrSync

### Group C: UI/UX Design (Can run parallel with Groups A+B)
- **Agents:** UXAgent, CreativeDirector
- **Tasks:** Phase 4 prep (Preset dialog design)
- **Duration:** 30 min
- **Coordination:** MrSync

### Group D: Testing (Sequential - depends on all implementation)
- **Agents:** MrTester, MrStupidUser
- **Tasks:** Phase 5 (Test coverage)
- **Duration:** 1.5 hours
- **Coordination:** MrSync

### Execution Diagram
```
Day 1 Morning (1.5h)          Day 1 Afternoon (2h)           Day 2 (3h)
┌─────────────────────┐       ┌──────────────────────┐      ┌──────────────────┐
│ Group A: Code       │       │ Group B: Mobile      │      │ Group D: Testing │
│ Quality             │──────▶│ Audio                │─────▶│                  │
│ (MrCleaner + Dev)   │       │ (Architect + Dev)    │      │ (MrTester)       │
└─────────────────────┘       └──────────────────────┘      └──────────────────┘
         │                              │                            │
         ▼                              ▼                            ▼
┌─────────────────────┐       ┌──────────────────────┐      ┌──────────────────┐
│ Group C: UI/UX      │       │ Group C: Presets UI  │      │ Group E: Docs    │
│ (UXAgent)           │──────▶│ (UXAgent + Dev)      │─────▶│ (MrLogger)       │
└─────────────────────┘       └──────────────────────┘      └──────────────────┘
```

---

## Quality Gates

### Quality Gate 1: Critical Fixes Complete
**Checkpoint:** After Phase 1 (30 min)
**Criteria:**
- [ ] `flutter analyze` returns 0 errors
- [ ] `metronome_preset.dart` compiles without const errors
- [ ] All unused imports removed
- [ ] Dead code eliminated

**Verification Command:**
```bash
flutter analyze lib/ 2>&1 | grep -E "error|warning" | wc -l
# Expected output: 0
```

### Quality Gate 2: Code Quality Complete
**Checkpoint:** After Phase 2 (45 min)
**Criteria:**
- [ ] All files formatted with `dart format`
- [ ] Info-level issues < 10 (or documented as acceptable)
- [ ] No `print` statements in production code
- [ ] No unused variables/methods

**Verification Command:**
```bash
dart format lib/ && flutter analyze lib/ 2>&1 | grep "info" | wc -l
# Expected output: <10
```

### Quality Gate 3: Mobile Audio Functional
**Checkpoint:** After Phase 3 (60 min)
**Criteria:**
- [ ] `audio_engine_mobile.dart` implemented with `audioplayers`
- [ ] Sound plays on Android emulator
- [ ] Volume control functional
- [ ] Wave type selection functional

**Verification:**
```bash
flutter build apk --release && adb install build/app/outputs/flutter-apk/app-release.apk
# Manual test: Open metronome, press Start, verify sound
```

### Quality Gate 4: Features Complete
**Checkpoint:** After Phase 4 (60 min)
**Criteria:**
- [ ] SongBPMBadge displays actual song BPM
- [ ] Tapping badge launches metronome with song BPM
- [ ] Preset save dialog functional
- [ ] Preset load dialog functional
- [ ] Presists across app restarts

**Verification:** Manual testing checklist

### Quality Gate 5: Test Coverage
**Checkpoint:** After Phase 5 (90 min)
**Criteria:**
- [ ] Unit test coverage ≥80% for services
- [ ] Widget test coverage ≥75% for widgets
- [ ] All tests pass: `flutter test`
- [ ] No test failures

**Verification Command:**
```bash
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html
# Open coverage/html/index.html, verify ≥80%
```

### Quality Gate 6: Documentation Complete
**Checkpoint:** After Phase 6 (60 min)
**Criteria:**
- [ ] README.md updated with metronome features
- [ ] CHANGELOG.md created with v0.10.0+1 changes
- [ ] ToDo.md updated with all revision tasks
- [ ] Session logged in `/log/20260222.md`

**Verification:** File existence check

---

## Expected Outcomes

### Deliverables

#### 1. Code Quality Report
**Location:** `/documentation/CODE_QUALITY_REPORT.md`
**Contents:**
- Before/after metrics (errors, warnings, info)
- Files modified
- Remaining technical debt (if any)

#### 2. Mobile Audio Implementation
**Location:** `/lib/services/audio_engine_mobile.dart`
**Contents:**
- Full `audioplayers` integration
- Platform-specific sound playback
- Volume and wave type controls

#### 3. Feature Completion
**Locations:**
- `/lib/widgets/song_bpm_badge.dart` (updated)
- `/lib/widgets/preset_dialog.dart` (new)
- `/lib/services/preset_service.dart` (new)

**Contents:**
- Song BPM badge with metronome integration
- Preset save/load UI
- Local storage for presets

#### 4. Test Suite
**Location:** `/test/`
**Contents:**
- `test/services/metronome_service_test.dart`
- `test/widgets/metronome_widget_test.dart`
- `test/widgets/tap_bpm_widget_test.dart`
- `test/integration/metronome_flow_test.dart`

#### 5. Documentation Updates
**Locations:**
- `/README.md` (updated)
- `/documentation/CHANGELOG.md` (new)
- `/documentation/ToDO.md` (updated)
- `/log/20260222.md` (session log)

#### 6. Release Package
**Location:** `/documentation/RELEASE_V0.10.1.md`
**Contents:**
- Version bump to 0.10.1+1
- Release notes
- Build artifacts checklist
- Deployment instructions

### Success Metrics

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| **Compilation Errors** | 8 | 0 | ✅ 0 |
| **Warnings** | 5 | 0 | ✅ 0 |
| **Info-level Issues** | 26 | <10 | ✅ <10 |
| **Test Coverage** | ~40% | ≥80% | ✅ ≥80% |
| **Mobile Audio** | ❌ Not implemented | ✅ Functional | ✅ Complete |
| **Song Integration** | ⏳ Partial | ✅ Complete | ✅ Complete |
| **Presets** | ⏳ Model only | ✅ UI + Storage | ✅ Complete |

### Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Mobile audio fails on Android | Medium | High | Fallback to web audio, document limitation |
| Test coverage <80% | Low | Medium | Prioritize critical paths, defer edge cases |
| Preset storage conflicts | Low | Medium | Use UUID for preset IDs, handle duplicates |
| Song integration breaks existing UI | Low | High | Feature flag, gradual rollout |

---

## Agent Assignment Summary

| Agent | Primary Tasks | Support Tasks | Time Allocation |
|-------|---------------|---------------|-----------------|
| **MrPlanner** | Plan coordination, phase gates | Progress tracking | 100% (all phases) |
| **MrSync** | Task assignment, scope enforcement | Documentation updates | 100% (all phases) |
| **MrSeniorDeveloper** | Code fixes, feature implementation | Code review | 80% (Phases 1-4) |
| **SystemArchitect** | Mobile audio architecture | Feature design | 50% (Phase 3) |
| **UXAgent** | Preset dialog design | Responsive verification | 50% (Phase 4) |
| **MrCleaner** | Code quality, formatting | Lint fixes | 60% (Phases 1-2) |
| **MrTester** | Test writing, coverage | Bug reporting | 70% (Phase 5) |
| **MrStupidUser** | User testing, UX feedback | Bug reporting | 30% (Phases 4-5) |
| **MrLogger** | Session logging, documentation | Metrics tracking | 50% (Phases 2, 5-6) |
| **CreativeDirector** | User journey review | Pattern consistency | 20% (Phase 4) |

---

## Execution Authorization

**Prepared by:** MrPlanner
**Date:** 2026-02-22
**Status:** Ready for MrSync coordination

**Next Steps:**
1. MrSync reviews and assigns tasks to agents
2. MrLogger creates session log at `/log/20260222.md`
3. MrCleaner runs initial `flutter analyze`
4. MrSeniorDeveloper begins Phase 1 fixes

**Total Estimated Duration:** 2 days (6 hours active work + buffers)
**Release Target:** v0.10.1+1

---

*Document generated in GOST Markdown format per project standards.*
