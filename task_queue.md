# 🏃 RepSync Flutter App - Sprint Task Queue

**Project:** RepSync Remediation
**Duration:** 4 Weeks (160 hours total)
**Start Date:** February 25, 2026
**End Date:** March 25, 2026

---

## 📊 SPRINT OVERVIEW

| Sprint | Focus | Duration | Hours | Status | Target Version |
|--------|-------|----------|-------|--------|----------------|
| **Sprint 1** | Critical Security & Stability | Week 1 | 40h | ✅ **COMPLETE** | v0.12.0 |
| **Sprint 2** | Architecture & Code Quality | Week 2 | 40h | ✅ **COMPLETE** | v0.13.0 |
| **Sprint 3** | Testing & QA | Week 3 | 40h | 🟡 In Progress | v0.14.0 |
| **Sprint 4** | Polish & Production | Week 4 | 40h | ⚪ Pending | v1.0.0 |

---

## ✅ SPRINT 1 COMPLETED

**Review Document:** `SPRINT_1_REVIEW.md`

### Achievements:
- ✅ All P0 security issues resolved (6/6 tasks)
- ✅ All memory leaks fixed (3/3 tasks)
- ✅ Tests passing (97%+ pass rate, 330+ tests)
- ✅ ~26 hours used (under capacity)

### Key Deliverables:
- 🔒 Removed hardcoded Spotify credentials
- 🔒 Restricted Firestore band access to members only
- 🔒 Added auth checks to all 15+ service methods
- 🔒 Implemented backend proxy pattern for Spotify API
- 🔒 Added comprehensive input validation in Firestore rules
- 🧹 Fixed ConnectivityService dispose pattern
- 🧹 Added stream subscription tracking in data providers
- 🧹 Added dispose() to all 7 Notifiers

**Version v0.12.0 is READY FOR RELEASE.**

---

## ✅ SPRINT 2 COMPLETED

**Review Document:** `SPRINT_2_REVIEW.md`

### Achievements:
- ✅ Repository pattern implemented (6/6 tasks)
- ✅ GoRouter fully integrated (8/8 tasks)
- ✅ Code cleanup completed (7/7 tasks)
- ✅ 32 new repository tests passing
- ✅ ~40 hours used (full capacity)

### Key Deliverables:
- 🏗️ Created SongRepository, BandRepository, SetlistRepository
- 🏗️ Migrated providers to use repositories
- 🚦 Implemented GoRouter with named routes
- 🚦 Added deep linking support
- 🧹 Extracted duplicate cache logic (60% reduction)
- 🧹 Removed unused providers/ui/ directory
- 🧹 Replaced print() with debugPrint()

**Version v0.13.0 is READY FOR RELEASE.**

---

**Review Document:** `SPRINT_1_REVIEW.md`

### Achievements:
- ✅ All P0 security issues resolved (6/6 tasks)
- ✅ All memory leaks fixed (3/3 tasks)
- ✅ Tests passing (97%+ pass rate, 330+ tests)
- ✅ ~26 hours used (under capacity)

### Key Deliverables:
- 🔒 Removed hardcoded Spotify credentials
- 🔒 Restricted Firestore band access to members only
- 🔒 Added auth checks to all 15+ service methods
- 🔒 Implemented backend proxy pattern for Spotify API
- 🔒 Added comprehensive input validation in Firestore rules
- 🧹 Fixed ConnectivityService dispose pattern
- 🧹 Added stream subscription tracking in data providers
- 🧹 Added dispose() to all 7 Notifiers

**Version v0.12.0 is READY FOR RELEASE.**

---

# 📍 SPRINT 1: Critical Security & Stability

**Duration:** Week 1 (February 25 - March 3, 2026)
**Capacity:** 40 hours
**Target Version:** v0.12.0

## Sprint Goal
> Eliminate all P0 security vulnerabilities and stability issues to establish a safe foundation for further development.

## Priority Summary

| Priority | Count | Hours | Focus |
|----------|-------|-------|-------|
| 🔴 P0 | 8 | 20h | Security & Memory Leaks |
| 🟠 P1 | 6 | 14h | Test Fixes & Logging |
| 🟡 P2 | 4 | 6h | Infrastructure |

---

## 🔐 SECURITY FIXES (20 hours)

### P0-SEC-01: Revoke & Regenerate Spotify Credentials
- **Estimate:** 30 min
- **Priority:** P0 🔴
- **Category:** Security
- **Assignee:** MrSeniorDeveloper

**Tasks:**
- [ ] Go to https://developer.spotify.com/dashboard
- [ ] Delete current app credentials
- [ ] Generate new Client ID and Client Secret
- [ ] Update local `.env` file (not committed)
- [ ] Verify Spotify API integration works with new credentials

**Acceptance Criteria:**
- [ ] Old credentials are revoked and unusable
- [ ] New credentials work in development
- [ ] Credentials are NOT committed to git

**Definition of Done:**
- [ ] Credentials rotated
- [ ] `.env` updated locally
- [ ] `.env.example` contains only placeholders

---

### P0-SEC-02: Remove Hardcoded Secrets from .env.example
- **Estimate:** 15 min
- **Priority:** P0 🔴
- **Category:** Security
- **File:** `.env.example`

**Tasks:**
- [ ] Replace `SPOTIFY_CLIENT_ID` value with `your_spotify_client_id_here`
- [ ] Replace `SPOTIFY_CLIENT_SECRET` value with `your_spotify_client_secret_here`
- [ ] Add warning comment about never committing real credentials
- [ ] Add to gitignore verification checklist

**Acceptance Criteria:**
- [ ] No real credentials in any example files
- [ ] Clear placeholder text with instructions
- [ ] Warning comment present

**Definition of Done:**
- [ ] File updated
- [ ] Committed to main branch

---

### P0-SEC-03: Fix Firestore Rules - Restrict Band Read Access
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Security
- **File:** `firestore.rules`

**Tasks:**
- [ ] Review current band read rules (line 73)
- [ ] Implement `isGlobalBandMember(bandId)` helper function
- [ ] Update band read rule to check membership
- [ ] Add test cases to `firestore.test.rules`
- [ ] Deploy rules to Firebase emulator for testing
- [ ] Test with authenticated non-member user

**Current (Vulnerable):**
```javascript
match /bands/{bandId} {
  allow read: if isAuthenticated();  // ❌ ANY authenticated user
}
```

**Target (Secure):**
```javascript
match /bands/{bandId} {
  allow read: if isAuthenticated() && isGlobalBandMember(bandId);
}
```

**Acceptance Criteria:**
- [ ] Non-members cannot read band data
- [ ] Members can read their band data
- [ ] Test rules pass in emulator
- [ ] Rules deployed to production Firebase

**Definition of Done:**
- [ ] Rules updated and tested
- [ ] Test coverage for security rules
- [ ] Deployed to production

---

### P0-SEC-04: Add Auth Checks to Service Methods
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Security
- **Files:** `firestore_service.dart`, `data_providers.dart`

**Tasks:**
- [ ] Audit all service methods for auth checks
- [ ] Add auth check to `getBandByInviteCode()` (line 378)
- [ ] Add auth check to band creation methods
- [ ] Add auth check to member management methods
- [ ] Create `requireAuth()` helper function
- [ ] Apply consistently across all services

**Acceptance Criteria:**
- [ ] All write operations require authentication
- [ ] All sensitive reads require authentication
- [ ] Unauthorized access throws `ApiError.authError()`
- [ ] Tests verify auth requirements

**Definition of Done:**
- [ ] All methods protected
- [ ] Tests passing
- [ ] Code reviewed

---

### P0-SEC-05: Implement Backend Proxy for Spotify API
- **Estimate:** 8 hours
- **Priority:** P0 🔴
- **Category:** Security
- **Files:** New Firebase Cloud Function, `spotify_service.dart`

**Tasks:**
- [ ] Create Firebase project functions directory
- [ ] Implement `spotifyToken` Cloud Function (Node.js/TypeScript)
- [ ] Store client secret in Firebase environment config
- [ ] Update `SpotifyService` to call Cloud Function
- [ ] Remove client secret from frontend code
- [ ] Add error handling for function failures
- [ ] Test token exchange flow
- [ ] Deploy Cloud Function

**Acceptance Criteria:**
- [ ] Client secret never exposed in frontend
- [ ] Token exchange works via Cloud Function
- [ ] Error handling graceful
- [ ] Secrets stored in Firebase config only

**Definition of Done:**
- [ ] Cloud Function deployed
- [ ] Frontend updated
- [ ] No secrets in client code
- [ ] Integration tested

---

### P0-SEC-06: Add Input Validation to Firestore Rules
- **Estimate:** 30 min
- **Priority:** P0 🔴
- **Category:** Security
- **File:** `firestore.rules`

**Tasks:**
- [ ] Add field validation for band creation
- [ ] Add field validation for song creation
- [ ] Add field validation for setlist creation
- [ ] Validate data types and required fields
- [ ] Add string length limits
- [ ] Test validation rules

**Acceptance Criteria:**
- [ ] Invalid data rejected by rules
- [ ] Required fields enforced
- [ ] Type validation working
- [ ] Tests cover validation

**Definition of Done:**
- [ ] Rules updated
- [ ] Tests passing
- [ ] Deployed

---

### P0-SEC-07: Band Creation Member Consent Verification
- **Estimate:** 3 hours
- **Priority:** P1 🟠
- **Category:** Security
- **Files:** `firestore_service.dart`, band models

**Tasks:**
- [ ] Review band creation flow
- [ ] Add member invitation acceptance flow
- [ ] Prevent adding members without consent
- [ ] Send invitation notifications
- [ ] Track invitation status
- [ ] Update UI for invitation flow

**Acceptance Criteria:**
- [ ] Members must accept invitations
- [ ] Cannot be added without consent
- [ ] Invitation status tracked
- [ ] UI shows pending invitations

**Definition of Done:**
- [ ] Flow implemented
- [ ] Tests passing
- [ ] UX reviewed

---

### P0-SEC-08: Rate Limiting for API Calls
- **Estimate:** 4 hours
- **Priority:** P2 🟡
- **Category:** Security
- **Files:** New rate limiter service

**Tasks:**
- [ ] Create `RateLimiterService`
- [ ] Implement token bucket algorithm
- [ ] Apply to Spotify API calls
- [ ] Apply to MusicBrainz API calls
- [ ] Add retry logic with backoff
- [ ] Log rate limit events

**Acceptance Criteria:**
- [ ] API calls rate limited
- [ ] Retry logic working
- [ ] No API bans
- [ ] Events logged

**Definition of Done:**
- [ ] Service implemented
- [ ] Applied to all APIs
- [ ] Tested under load

---

## 🧠 MEMORY LEAK FIXES (10 hours)

### P0-MEM-01: Fix ConnectivityService Dispose
- **Estimate:** 30 min
- **Priority:** P0 🔴
- **Category:** Memory
- **File:** `lib/services/connectivity_service.dart`

**Tasks:**
- [ ] Add `StreamSubscription` field for connectivity stream
- [ ] Store subscription in constructor/init
- [ ] Implement `dispose()` method
- [ ] Cancel subscription in dispose
- [ ] Make class implement `Disposable` or mixin
- [ ] Test with Flutter DevTools memory profiler

**Acceptance Criteria:**
- [ ] Subscription properly cancelled
- [ ] No memory leak in profiler
- [ ] dispose() called when service no longer needed

**Definition of Done:**
- [ ] Code fixed
- [ ] Memory tested
- [ ] No leaks detected

---

### P0-MEM-02: Fix Stream Subscriptions in Data Providers
- **Estimate:** 4 hours
- **Priority:** P0 🔴
- **Category:** Memory
- **File:** `lib/providers/data/data_providers.dart`

**Tasks:**
- [ ] Identify all stream subscriptions (lines 84, 138, 239, 323, 367)
- [ ] Store each subscription in class field
- [ ] Add `dispose()` override to each provider
- [ ] Cancel all subscriptions in dispose
- [ ] Use `autoDispose` modifier where appropriate
- [ ] Test each provider with memory profiler

**Acceptance Criteria:**
- [ ] All 5+ subscriptions properly disposed
- [ ] No memory leaks in any provider
- [ ] Providers use autoDispose where applicable

**Definition of Done:**
- [ ] All providers fixed
- [ ] Memory tested
- [ ] Code reviewed

---

### P0-MEM-03: Add Dispose to All Notifiers
- **Estimate:** 4 hours
- **Priority:** P0 🔴
- **Category:** Memory
- **Files:** All Riverpod Notifier classes

**Tasks:**
- [ ] Audit all Notifier classes for dispose needs
- [ ] Add `dispose()` override where needed
- [ ] Cancel subscriptions in dispose
- [ ] Clean up timers
- [ ] Clean up controllers
- [ ] Document dispose patterns

**Acceptance Criteria:**
- [ ] All Notifiers properly dispose resources
- [ ] No orphaned subscriptions
- [ ] No orphaned timers

**Definition of Done:**
- [ ] All Notifiers fixed
- [ ] Memory tested
- [ ] Documentation added

---

### P0-MEM-04: Memory Profiler Testing
- **Estimate:** 1.5 hours
- **Priority:** P1 🟠
- **Category:** Memory
- **Tools:** Flutter DevTools

**Tasks:**
- [ ] Open Flutter DevTools memory profiler
- [ ] Navigate through all app screens
- [ ] Take memory snapshots
- [ ] Compare snapshots for leaks
- [ ] Document baseline memory usage
- [ ] Verify fixes from P0-MEM-01/02/03

**Acceptance Criteria:**
- [ ] Memory stable after navigation cycles
- [ ] No growing memory footprint
- [ ] Baseline documented

**Definition of Done:**
- [ ] Profiling complete
- [ ] Results documented
- [ ] No leaks found

---

## 🧪 TEST FIXES (8 hours)

### P0-TST-01: Fix 122 Failing Tests
- **Estimate:** 4 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **Files:** Multiple test files

**Tasks:**
- [ ] Run `flutter test` and capture all failures
- [ ] Fix Mockito integration tests (19 tests, 1 hour)
  - [ ] Update mock setups for new interfaces
  - [ ] Fix stubbing mismatches
- [ ] Fix missing MetronomeState import (24 errors, 30 min)
  - [ ] Add missing imports
  - [ ] Verify test compiles
- [ ] Fix Material widget in test helpers (9 tests, 1 hour)
  - [ ] Wrap with MaterialApp in helpers
  - [ ] Update test pump methods
- [ ] Fix remaining failures (1.5 hours)
  - [ ] Categorize by failure type
  - [ ] Fix systematically

**Acceptance Criteria:**
- [ ] All 122 tests passing
- [ ] 100% test pass rate
- [ ] No compilation errors

**Definition of Done:**
- [ ] All tests pass
- [ ] CI pipeline green
- [ ] Code reviewed

---

### P0-TST-02: Setup GitHub Actions CI Pipeline
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **Files:** `.github/workflows/ci.yml`

**Tasks:**
- [ ] Create `.github/workflows` directory
- [ ] Create `ci.yml` workflow file
- [ ] Configure Flutter action
- [ ] Add test job with coverage
- [ ] Add build job for web
- [ ] Add build job for Android
- [ ] Configure branch protection rules
- [ ] Test workflow on PR

**Acceptance Criteria:**
- [ ] CI runs on every push
- [ ] Tests run automatically
- [ ] Coverage reported
- [ ] Build artifacts produced

**Definition of Done:**
- [ ] Workflow created
- [ ] Successfully runs
- [ ] Branch protection configured

---

### P0-TST-03: Add Coverage Threshold Enforcement
- **Estimate:** 1 hour
- **Priority:** P1 🟠
- **Category:** Testing
- **Files:** `ci.yml`, `pubspec.yaml`

**Tasks:**
- [ ] Configure coverage collection in CI
- [ ] Add coverage threshold (minimum 50% for Sprint 1)
- [ ] Fail CI if threshold not met
- [ ] Add coverage badge to README
- [ ] Document coverage requirements

**Acceptance Criteria:**
- [ ] Coverage collected on CI
- [ ] Threshold enforced
- [ ] Badge visible in README

**Definition of Done:**
- [ ] CI configured
- [ ] Threshold set
- [ ] Badge added

---

### P0-TST-04: Document Testing Conventions
- **Estimate:** 30 min
- **Priority:** P2 🟡
- **Category:** Testing
- **Files:** `TESTING.md` or `CONTRIBUTING.md`

**Tasks:**
- [ ] Document test file naming conventions
- [ ] Document mock setup patterns
- [ ] Document async testing patterns
- [ ] Document golden test guidelines
- [ ] Add examples

**Acceptance Criteria:**
- [ ] Conventions documented
- [ ] Examples provided
- [ ] Team can follow

**Definition of Done:**
- [ ] Documentation written
- [ ] Committed to main

---

## 📝 LOGGING INFRASTRUCTURE (2 hours)

### P1-LOG-01: Create LoggerService
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Logging
- **File:** `lib/services/logger_service.dart`

**Tasks:**
- [ ] Create `LogLevel` enum (verbose, debug, info, warning, error, fatal)
- [ ] Create `LoggerConfig` class
- [ ] Implement `LoggerService` with static history
- [ ] Add convenience methods (v, d, i, w, e, f)
- [ ] Add execution timing helpers
- [ ] Configure for dev vs production
- [ ] Replace `ErrorNotifier` debugPrint with LoggerService

**Acceptance Criteria:**
- [ ] LoggerService functional
- [ ] Log levels working
- [ ] History tracking works
- [ ] Production config strips debug logs

**Definition of Done:**
- [ ] Service implemented
- [ ] Tests passing
- [ ] Integrated with ErrorNotifier

---

## 📋 SPRINT 1 CHECKLIST

### Security
- [ ] P0-SEC-01: Revoke Spotify credentials
- [ ] P0-SEC-02: Remove hardcoded secrets
- [ ] P0-SEC-03: Fix Firestore rules
- [ ] P0-SEC-04: Add auth checks
- [ ] P0-SEC-05: Backend proxy for Spotify
- [ ] P0-SEC-06: Input validation rules
- [ ] P0-SEC-07: Member consent verification
- [ ] P0-SEC-08: Rate limiting

### Memory
- [ ] P0-MEM-01: Fix ConnectivityService
- [ ] P0-MEM-02: Fix Data Providers
- [ ] P0-MEM-03: Fix All Notifiers
- [ ] P0-MEM-04: Memory profiler testing

### Testing
- [ ] P0-TST-01: Fix 122 failing tests
- [ ] P0-TST-02: Setup GitHub Actions CI
- [ ] P0-TST-03: Coverage threshold enforcement
- [ ] P0-TST-04: Document testing conventions

### Logging
- [ ] P1-LOG-01: Create LoggerService

---

## 📊 SPRINT 1 SUCCESS METRICS

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Security Score | 4.0/10 | 9.0/10 | ⬜ |
| Critical Issues | 12 | 0 | ⬜ |
| Memory Leaks | 5+ | 0 | ⬜ |
| Test Pass Rate | 76.6% | 100% | ⬜ |
| Test Coverage | 39.8% | 50% | ⬜ |
| CI/CD | None | Basic | ⬜ |

---

## 🔄 SPRINT 1 REVIEW & RETROSPECTIVE

### Sprint Review (March 3, 2026)

**Demo Items:**
- [ ] Security fixes demonstrated
- [ ] Memory leak fixes shown in DevTools
- [ ] CI pipeline running
- [ ] LoggerService in action

**Stakeholders:**
- [ ] Product Owner
- [ ] Development Team
- [ ] Security Reviewer

### Sprint Retrospective

**What Went Well:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**What Could Be Improved:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**Action Items for Sprint 2:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

---

# 📍 SPRINT 2: Architecture & Code Quality

**Duration:** Week 2 (March 4 - March 10, 2026)
**Capacity:** 40 hours
**Target Version:** v0.13.0

## Sprint Goal
> Refactor monolithic services into clean architecture with repository pattern, migrate to GoRouter, and eliminate code quality debt.

## Priority Summary

| Priority | Count | Hours | Focus |
|----------|-------|-------|-------|
| 🔴 P0 | 6 | 18h | Repository Pattern |
| 🟠 P1 | 8 | 16h | Router Migration |
| 🟡 P2 | 5 | 6h | Code Cleanup |

---

## 🏗️ REPOSITORY PATTERN (18 hours)

### P0-ARC-01: Create SongRepository Interface
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Architecture
- **Files:** `lib/repositories/song_repository.dart`

**Tasks:**
- [ ] Define `SongRepository` abstract class
- [ ] Define CRUD methods (create, read, update, delete)
- [ ] Define query methods (byBand, byUser, search)
- [ ] Define stream methods for reactive updates
- [ ] Add error handling contract
- [ ] Document interface

**Acceptance Criteria:**
- [ ] Interface complete
- [ ] All CRUD operations defined
- [ ] Stream methods defined
- [ ] Documentation complete

**Definition of Done:**
- [ ] Interface created
- [ ] Documented
- [ ] Reviewed

---

### P0-ARC-02: Create BandRepository Interface
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Architecture
- **Files:** `lib/repositories/band_repository.dart`

**Tasks:**
- [ ] Define `BandRepository` abstract class
- [ ] Define band CRUD methods
- [ ] Define member management methods
- [ ] Define invite code methods
- [ ] Define stream methods
- [ ] Document interface

**Acceptance Criteria:**
- [ ] Interface complete
- [ ] Member management defined
- [ ] Stream methods defined

**Definition of Done:**
- [ ] Interface created
- [ ] Documented
- [ ] Reviewed

---

### P0-ARC-03: Create SetlistRepository Interface
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Architecture
- **Files:** `lib/repositories/setlist_repository.dart`

**Tasks:**
- [ ] Define `SetlistRepository` abstract class
- [ ] Define setlist CRUD methods
- [ ] Define song ordering methods
- [ ] Define duration calculation
- [ ] Define stream methods
- [ ] Document interface

**Acceptance Criteria:**
- [ ] Interface complete
- [ ] All operations defined
- [ ] Stream methods defined

**Definition of Done:**
- [ ] Interface created
- [ ] Documented
- [ ] Reviewed

---

### P0-ARC-04: Implement FirestoreSongRepository
- **Estimate:** 3 hours
- **Priority:** P0 🔴
- **Category:** Architecture
- **Files:** `lib/repositories/firestore_song_repository.dart`

**Tasks:**
- [ ] Implement `SongRepository` interface
- [ ] Migrate logic from `FirestoreService`
- [ ] Add caching layer integration
- [ ] Add error handling
- [ ] Add logging with LoggerService
- [ ] Write unit tests

**Acceptance Criteria:**
- [ ] All interface methods implemented
- [ ] Tests passing
- [ ] Caching integrated
- [ ] Logging present

**Definition of Done:**
- [ ] Implementation complete
- [ ] Tests passing
- [ ] Code reviewed

---

### P0-ARC-05: Implement FirestoreBandRepository
- **Estimate:** 3 hours
- **Priority:** P0 🔴
- **Category:** Architecture
- **Files:** `lib/repositories/firestore_band_repository.dart`

**Tasks:**
- [ ] Implement `BandRepository` interface
- [ ] Migrate logic from `FirestoreService`
- [ ] Add security checks
- [ ] Add caching layer
- [ ] Add logging
- [ ] Write unit tests

**Acceptance Criteria:**
- [ ] All methods implemented
- [ ] Security checks present
- [ ] Tests passing

**Definition of Done:**
- [ ] Implementation complete
- [ ] Tests passing
- [ ] Code reviewed

---

### P0-ARC-06: Migrate Providers to Use Repositories
- **Estimate:** 6 hours
- **Priority:** P0 🔴
- **Category:** Architecture
- **Files:** `lib/providers/data/data_providers.dart`

**Tasks:**
- [ ] Inject repositories into providers
- [ ] Update all data providers
- [ ] Remove direct FirestoreService usage
- [ ] Update provider tests
- [ ] Integration testing
- [ ] Document migration

**Acceptance Criteria:**
- [ ] All providers use repositories
- [ ] No direct FirestoreService usage
- [ ] All tests passing
- [ ] Functionality unchanged

**Definition of Done:**
- [ ] Migration complete
- [ ] Tests passing
- [ ] Documentation updated

---

## 🧭 ROUTER MIGRATION (16 hours)

### P1-RTR-01: Migrate to GoRouter
- **Estimate:** 4 hours
- **Priority:** P1 🟠
- **Category:** Architecture
- **Files:** `lib/router/app_router.dart`, `lib/main.dart`

**Tasks:**
- [ ] Review existing GoRouter configuration
- [ ] Define all routes with GoRouter syntax
- [ ] Migrate from manual routes map
- [ ] Update navigation calls throughout app
- [ ] Test all navigation flows
- [ ] Remove old router code

**Acceptance Criteria:**
- [ ] All routes migrated
- [ ] Navigation working
- [ ] Old code removed
- [ ] Tests passing

**Definition of Done:**
- [ ] Migration complete
- [ ] All flows tested
- [ ] Code reviewed

---

### P1-RTR-02: Add Type-Safe Navigation
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Architecture
- **Files:** `lib/router/app_router.dart`

**Tasks:**
- [ ] Define route parameter classes
- [ ] Add type-safe route helpers
- [ ] Create navigation extension methods
- [ ] Update all navigation calls
- [ ] Document usage

**Acceptance Criteria:**
- [ ] Type-safe navigation working
- [ ] Compile-time route checking
- [ ] Documentation complete

**Definition of Done:**
- [ ] Type safety implemented
- [ ] All calls updated
- [ ] Documented

---

### P1-RTR-03: Remove Manual Routes Map
- **Estimate:** 1 hour
- **Priority:** P1 🟠
- **Category:** Architecture
- **Files:** `lib/router/`, `lib/screens/`

**Tasks:**
- [ ] Find all references to old routes map
- [ ] Remove routes map file
- [ ] Update imports
- [ ] Clean up unused code
- [ ] Run analyzer

**Acceptance Criteria:**
- [ ] No references to old routes
- [ ] Code compiles
- [ ] Analyzer clean

**Definition of Done:**
- [ ] Old code removed
- [ ] Analyzer clean

---

### P1-RTR-04: Add Deep Linking Support
- **Estimate:** 3 hours
- **Priority:** P1 🟠
- **Category:** Architecture
- **Files:** `lib/router/app_router.dart`, platform configs

**Tasks:**
- [ ] Configure GoRouter for deep links
- [ ] Define deep link patterns
- [ ] Add web URL strategy
- [ ] Configure Android intent filters
- [ ] Configure iOS universal links
- [ ] Test deep links on all platforms

**Acceptance Criteria:**
- [ ] Deep links work on web
- [ ] Deep links work on Android
- [ ] Deep links work on iOS
- [ ] All patterns tested

**Definition of Done:**
- [ ] Deep linking configured
- [ ] All platforms tested
- [ ] Documentation updated

---

### P1-RTR-05: Test All Navigation Flows
- **Estimate:** 3 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **Files:** Test files

**Tasks:**
- [ ] Create navigation test suite
- [ ] Test auth flow navigation
- [ ] Test band management navigation
- [ ] Test song management navigation
- [ ] Test setlist navigation
- [ ] Test deep link navigation
- [ ] Document test results

**Acceptance Criteria:**
- [ ] All flows tested
- [ ] Tests passing
- [ ] Results documented

**Definition of Done:**
- [ ] Tests created
- [ ] All passing
- [ ] Documented

---

### P1-RTR-06: Router Documentation & Rollback Plan
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** Documentation
- **Files:** `docs/ROUTER_MIGRATION.md`

**Tasks:**
- [ ] Document router architecture
- [ ] Document route patterns
- [ ] Create rollback plan
- [ ] Document troubleshooting
- [ ] Add to PROJECT.md

**Acceptance Criteria:**
- [ ] Documentation complete
- [ ] Rollback plan clear
- [ ] Team can reference

**Definition of Done:**
- [ ] Documentation written
- [ ] Committed

---

### P1-RTR-07: Code Review - Router Migration
- **Estimate:** 1 hour
- **Priority:** P2 🟡
- **Category:** Review
- **Assignee:** MrSeniorDeveloper

**Tasks:**
- [ ] Review all router changes
- [ ] Check for edge cases
- [ ] Verify error handling
- [ ] Sign off on migration

**Acceptance Criteria:**
- [ ] Code reviewed
- [ ] Issues addressed
- [ ] Approved for merge

**Definition of Done:**
- [ ] Review complete
- [ ] Approved

---

## 🧹 CODE CLEANUP (6 hours)

### P2-CLN-01: Extract Duplicate Cache Logic
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** Code Quality
- **Files:** `lib/providers/data/`, `lib/services/cache_service.dart`

**Tasks:**
- [ ] Identify duplicate cache-first patterns (4 occurrences)
- [ ] Create generic `CachedStreamNotifier<T>` base class
- [ ] Refactor providers to use base class
- [ ] Remove duplicate code
- [ ] Test refactored providers

**Acceptance Criteria:**
- [ ] No duplicate cache logic
- [ ] Generic base class working
- [ ] All tests passing

**Definition of Done:**
- [ ] Refactoring complete
- [ ] Tests passing
- [ ] Code reviewed

---

### P2-CLN-02: Remove Unused Directories
- **Estimate:** 30 min
- **Priority:** P2 🟡
- **Category:** Code Quality
- **Files:** `lib/providers/ui/`

**Tasks:**
- [ ] Audit `providers/ui/` directory
- [ ] Confirm no usage in codebase
- [ ] Remove directory
- [ ] Update any imports
- [ ] Run analyzer

**Acceptance Criteria:**
- [ ] Unused code removed
- [ ] No broken imports
- [ ] Analyzer clean

**Definition of Done:**
- [ ] Directory removed
- [ ] Analyzer clean

---

### P2-CLN-03: Replace Print with DebugPrint/Logger
- **Estimate:** 1 hour
- **Priority:** P2 🟡
- **Category:** Code Quality
- **Files:** Multiple (47 print statements)

**Tasks:**
- [ ] Find all `print()` statements
- [ ] Replace with `LoggerService` or `debugPrint`
- [ ] Guard with kDebugMode where needed
- [ ] Run analyzer
- [ ] Test logging output

**Acceptance Criteria:**
- [ ] No unsafe print statements
- [ ] All logging uses LoggerService
- [ ] Production-safe

**Definition of Done:**
- [ ] All replaced
- [ ] Tested
- [ ] Analyzer clean

---

### P2-CLN-04: Fix Duplicate State in MainShell
- **Estimate:** 1 hour
- **Priority:** P2 🟡
- **Category:** Code Quality
- **Files:** `lib/screens/main_shell.dart`

**Tasks:**
- [ ] Identify duplicate state (`_currentIndex` + `bottomNavIndexProvider`)
- [ ] Choose single source of truth
- [ ] Remove duplicate
- [ ] Update all references
- [ ] Test navigation

**Acceptance Criteria:**
- [ ] Single source of truth
- [ ] Navigation working
- [ ] No regressions

**Definition of Done:**
- [ ] Duplicate removed
- [ ] Tests passing

---

### P2-CLN-05: Run dart analyze --fatal-infos
- **Estimate:** 30 min
- **Priority:** P2 🟡
- **Category:** Code Quality

**Tasks:**
- [ ] Run `dart analyze --fatal-infos`
- [ ] Fix all errors
- [ ] Fix all warnings
- [ ] Fix all infos
- [ ] Add to CI pipeline

**Acceptance Criteria:**
- [ ] Zero errors
- [ ] Zero warnings
- [ ] Zero infos

**Definition of Done:**
- [ ] Analyzer clean
- [ ] CI configured

---

## 📋 SPRINT 2 CHECKLIST

### Repository Pattern
- [ ] P0-ARC-01: SongRepository interface
- [ ] P0-ARC-02: BandRepository interface
- [ ] P0-ARC-03: SetlistRepository interface
- [ ] P0-ARC-04: FirestoreSongRepository
- [ ] P0-ARC-05: FirestoreBandRepository
- [ ] P0-ARC-06: Migrate providers

### Router Migration
- [ ] P1-RTR-01: Migrate to GoRouter
- [ ] P1-RTR-02: Type-safe navigation
- [ ] P1-RTR-03: Remove manual routes
- [ ] P1-RTR-04: Deep linking
- [ ] P1-RTR-05: Test navigation flows
- [ ] P1-RTR-06: Documentation
- [ ] P1-RTR-07: Code review

### Code Cleanup
- [ ] P2-CLN-01: Extract cache logic
- [ ] P2-CLN-02: Remove unused directories
- [ ] P2-CLN-03: Replace print statements
- [ ] P2-CLN-04: Fix duplicate state
- [ ] P2-CLN-05: dart analyze

---

## 📊 SPRINT 2 SUCCESS METRICS

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Architecture Score | 6.5/10 | 8.0/10 | ⬜ |
| God Classes | 1 | 0 | ⬜ |
| Duplicate Code | 4 instances | 0 | ⬜ |
| Analyzer Issues | 47+ | 0 | ⬜ |
| Router Coverage | 0% | 100% | ⬜ |

---

## 🔄 SPRINT 2 REVIEW & RETROSPECTIVE

### Sprint Review (March 10, 2026)

**Demo Items:**
- [ ] Repository pattern demonstrated
- [ ] GoRouter navigation shown
- [ ] Deep linking working
- [ ] Code quality improvements

**Stakeholders:**
- [ ] Product Owner
- [ ] Development Team
- [ ] Architecture Reviewer

### Sprint Retrospective

**What Went Well:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**What Could Be Improved:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**Action Items for Sprint 3:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

---

# 📍 SPRINT 3: Testing & QA

**Duration:** Week 3 (March 11 - March 17, 2026)
**Capacity:** 40 hours
**Target Version:** v0.14.0

## Sprint Goal
> Achieve 75%+ test coverage with comprehensive service, provider, and integration tests to ensure quality and prevent regressions.

## Priority Summary

| Priority | Count | Hours | Focus |
|----------|-------|-------|-------|
| 🔴 P0 | 12 | 24h | Service Tests |
| 🟠 P1 | 8 | 12h | Provider Tests |
| 🟡 P2 | 4 | 4h | Integration Tests |

---

## 🔧 SERVICE TESTS (24 hours)

### P0-SVC-01: Spotify Service Tests
- **Estimate:** 4 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/spotify_service_test.dart`

**Tasks:**
- [ ] Mock HTTP client
- [ ] Test token exchange
- [ ] Test track analysis
- [ ] Test BPM detection
- [ ] Test key detection
- [ ] Test error handling
- [ ] Test rate limiting
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All methods tested
- [ ] Error cases covered
- [ ] 80%+ coverage
- [ ] Tests passing

**Definition of Done:**
- [ ] Tests written
- [ ] All passing
- [ ] Coverage met

---

### P0-SVC-02: MusicBrainz Service Tests
- **Estimate:** 3 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/musicbrainz_service_test.dart`

**Tasks:**
- [ ] Mock HTTP client
- [ ] Test search functionality
- [ ] Test metadata retrieval
- [ ] Test error handling
- [ ] Test caching
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All methods tested
- [ ] 80%+ coverage
- [ ] Tests passing

**Definition of Done:**
- [ ] Tests written
- [ ] All passing
- [ ] Coverage met

---

### P0-SVC-03: Track Analysis Service Tests
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/track_analysis_service_test.dart`

**Tasks:**
- [ ] Mock dependencies
- [ ] Test analysis flow
- [ ] Test result parsing
- [ ] Test error handling
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All flows tested
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-04: PDF Export Service Tests
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/pdf_service_test.dart`

**Tasks:**
- [ ] Mock PDF dependencies
- [ ] Test setlist rendering
- [ ] Test formatting
- [ ] Test error handling
- [ ] Golden tests for output
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] Export tested
- [ ] Golden tests pass
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] Golden tests added
- [ ] Coverage met

---

### P0-SVC-05: Audio Service Tests
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/audio_service_test.dart`

**Tasks:**
- [ ] Mock audio platform
- [ ] Test playback
- [ ] Test pause/stop
- [ ] Test volume control
- [ ] Test error handling
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All methods tested
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-06: Cache Service Tests
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/cache_service_test.dart`

**Tasks:**
- [ ] Mock Hive
- [ ] Test cache write
- [ ] Test cache read
- [ ] Test cache invalidation
- [ ] Test TTL
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All operations tested
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-07: Connectivity Service Tests
- **Estimate:** 1 hour
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/connectivity_service_test.dart`

**Tasks:**
- [ ] Mock connectivity plugin
- [ ] Test online detection
- [ ] Test offline detection
- [ ] Test stream
- [ ] Test dispose
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All methods tested
- [ ] Dispose verified
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-08: Firestore Service Tests
- **Estimate:** 3 hours
- **Priority:** P0 🔴
- **Category:** Testing
- **File:** `test/services/firestore_service_test.dart`

**Tasks:**
- [ ] Mock Firestore
- [ ] Test CRUD operations
- [ ] Test queries
- [ ] Test streams
- [ ] Test error handling
- [ ] Test security
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All operations tested
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-09: CSV Service Tests
- **Estimate:** 1 hour
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/services/csv_service_test.dart`

**Tasks:**
- [ ] Test CSV export
- [ ] Test CSV import
- [ ] Test parsing
- [ ] Test error handling
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] Import/export tested
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-10: Logger Service Tests
- **Estimate:** 1 hour
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/services/logger_service_test.dart`

**Tasks:**
- [ ] Test log levels
- [ ] Test history
- [ ] Test filtering
- [ ] Test export
- [ ] Test config
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- [ ] All features tested
- [ ] 80%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-11: Error Provider Tests
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/providers/error_provider_test.dart`

**Tasks:**
- [ ] Test error handling
- [ ] Test error state
- [ ] Test history
- [ ] Test clear
- [ ] Achieve 85%+ coverage

**Acceptance Criteria:**
- [ ] All methods tested
- [ ] 85%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P0-SVC-12: Auth Provider Tests
- **Estimate:** 3 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/providers/auth_provider_test.dart`

**Tasks:**
- [ ] Mock Firebase Auth
- [ ] Test sign in
- [ ] Test sign up
- [ ] Test sign out
- [ ] Test password reset
- [ ] Test Google sign in
- [ ] Test error handling
- [ ] Achieve 85%+ coverage

**Acceptance Criteria:**
- [ ] All auth flows tested
- [ ] 85%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

## 📊 PROVIDER TESTS (12 hours)

### P1-PRV-01: Data Provider Tests
- **Estimate:** 4 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/providers/data_providers_test.dart`

**Tasks:**
- [ ] Mock repositories
- [ ] Test bands provider
- [ ] Test songs provider
- [ ] Test setlists provider
- [ ] Test streams
- [ ] Test error handling
- [ ] Achieve 85%+ coverage

**Acceptance Criteria:**
- [ ] All providers tested
- [ ] 85%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P1-PRV-02: Metronome Provider Tests
- **Estimate:** 3 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/providers/metronome_provider_test.dart`

**Tasks:**
- [ ] Test state changes
- [ ] Test BPM changes
- [ ] Test time signature
- [ ] Test accent patterns
- [ ] Test presets
- [ ] Achieve 85%+ coverage

**Acceptance Criteria:**
- [ ] All state tested
- [ ] 85%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P1-PRV-03: Tuner Provider Tests
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/providers/tuner_provider_test.dart`

**Tasks:**
- [ ] Mock audio input
- [ ] Test pitch detection
- [ ] Test note calculation
- [ ] Test cents offset
- [ ] Achieve 85%+ coverage

**Acceptance Criteria:**
- [ ] All methods tested
- [ ] 85%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P1-PRV-04: UI Provider Tests
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/providers/ui_providers_test.dart`

**Tasks:**
- [ ] Test theme provider
- [ ] Test loading states
- [ ] Test dialog states
- [ ] Test snackbar states
- [ ] Achieve 85%+ coverage

**Acceptance Criteria:**
- [ ] All UI states tested
- [ ] 85%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

### P1-PRV-05: Error Provider Tests
- **Estimate:** 1 hour
- **Priority:** P1 🟠
- **Category:** Testing
- **File:** `test/providers/error_provider_test.dart`

**Tasks:**
- [ ] Test error handling
- [ ] Test error display
- [ ] Test error clearing
- [ ] Achieve 85%+ coverage

**Acceptance Criteria:**
- [ ] All methods tested
- [ ] 85%+ coverage

**Definition of Done:**
- [ ] Tests written
- [ ] All passing

---

## 🔗 INTEGRATION TESTS (4 hours)

### P2-INT-01: Song Creation Flow
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** Testing
- **File:** `test/integration/song_creation_test.dart`

**Tasks:**
- [ ] Navigate to add song screen
- [ ] Fill song form
- [ ] Save song
- [ ] Verify in list
- [ ] Test edit
- [ ] Test delete

**Acceptance Criteria:**
- [ ] Full flow works
- [ ] Data persists
- [ ] No errors

**Definition of Done:**
- [ ] Test written
- [ ] Passing
- [ ] Documented

---

### P2-INT-02: Band Management Flow
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** Testing
- **File:** `test/integration/band_management_test.dart`

**Tasks:**
- [ ] Create band
- [ ] Generate invite code
- [ ] Join band (second user)
- [ ] Manage members
- [ ] Test roles
- [ ] Test permissions

**Acceptance Criteria:**
- [ ] Full flow works
- [ ] Permissions enforced
- [ ] No errors

**Definition of Done:**
- [ ] Test written
- [ ] Passing
- [ ] Documented

---

### P2-INT-03: Setlist Creation Flow
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** Testing
- **File:** `test/integration/setlist_creation_test.dart`

**Tasks:**
- [ ] Create setlist
- [ ] Add songs
- [ ] Reorder songs
- [ ] Calculate duration
- [ ] Export PDF
- [ ] Share setlist

**Acceptance Criteria:**
- [ ] Full flow works
- [ ] Export works
- [ ] No errors

**Definition of Done:**
- [ ] Test written
- [ ] Passing
- [ ] Documented

---

### P2-INT-04: User Authentication Flow
- **Estimate:** 1 hour
- **Priority:** P2 🟡
- **Category:** Testing
- **File:** `test/integration/auth_flow_test.dart`

**Tasks:**
- [ ] Register new user
- [ ] Verify email
- [ ] Sign in
- [ ] Sign out
- [ ] Password reset
- [ ] Google sign in

**Acceptance Criteria:**
- [ ] All auth flows work
- [ ] No errors

**Definition of Done:**
- [ ] Test written
- [ ] Passing
- [ ] Documented

---

### P2-INT-05: Offline Sync Flow
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** Testing
- **File:** `test/integration/offline_sync_test.dart`

**Tasks:**
- [ ] Go offline
- [ ] Create/edit data
- [ ] Verify cached
- [ ] Go online
- [ ] Verify synced
- [ ] Test conflict resolution

**Acceptance Criteria:**
- [ ] Offline works
- [ ] Sync works
- [ ] No data loss

**Definition of Done:**
- [ ] Test written
- [ ] Passing
- [ ] Documented

---

## 📋 SPRINT 3 CHECKLIST

### Service Tests
- [ ] P0-SVC-01: Spotify service
- [ ] P0-SVC-02: MusicBrainz service
- [ ] P0-SVC-03: Track analysis
- [ ] P0-SVC-04: PDF export
- [ ] P0-SVC-05: Audio service
- [ ] P0-SVC-06: Cache service
- [ ] P0-SVC-07: Connectivity service
- [ ] P0-SVC-08: Firestore service
- [ ] P0-SVC-09: CSV service
- [ ] P0-SVC-10: Logger service
- [ ] P0-SVC-11: Error provider
- [ ] P0-SVC-12: Auth provider

### Provider Tests
- [ ] P1-PRV-01: Data providers
- [ ] P1-PRV-02: Metronome provider
- [ ] P1-PRV-03: Tuner provider
- [ ] P1-PRV-04: UI providers
- [ ] P1-PRV-05: Error provider

### Integration Tests
- [ ] P2-INT-01: Song creation
- [ ] P2-INT-02: Band management
- [ ] P2-INT-03: Setlist creation
- [ ] P2-INT-04: Auth flow
- [ ] P2-INT-05: Offline sync

---

## 📊 SPRINT 3 SUCCESS METRICS

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Test Coverage | 50% | 75% | ⬜ |
| Service Coverage | 0% | 80% | ⬜ |
| Provider Coverage | 17.5% | 85% | ⬜ |
| Integration Tests | 0 | 5 | ⬜ |
| Test Pass Rate | 100% | 100% | ⬜ |

---

## 🔄 SPRINT 3 REVIEW & RETROSPECTIVE

### Sprint Review (March 17, 2026)

**Demo Items:**
- [ ] Service tests demonstrated
- [ ] Provider tests shown
- [ ] Integration tests running
- [ ] Coverage report

**Stakeholders:**
- [ ] Product Owner
- [ ] Development Team
- [ ] QA Reviewer

### Sprint Retrospective

**What Went Well:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**What Could Be Improved:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**Action Items for Sprint 4:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

---

# 📍 SPRINT 4: Polish & Production

**Duration:** Week 4 (March 18 - March 25, 2026)
**Capacity:** 40 hours
**Target Version:** v1.0.0

## Sprint Goal
> Achieve Android production readiness, complete UI/UX improvements, and implement production monitoring for v1.0.0 release.

## Priority Summary

| Priority | Count | Hours | Focus |
|----------|-------|-------|-------|
| 🔴 P0 | 8 | 16h | Android Production |
| 🟠 P1 | 8 | 16h | UI/UX Improvements |
| 🟡 P2 | 4 | 8h | Logging & Monitoring |

---

## 📱 ANDROID PRODUCTION (16 hours)

### P0-AND-01: Set Explicit SDK Versions
- **Estimate:** 30 min
- **Priority:** P0 🔴
- **Category:** Android
- **File:** `android/app/build.gradle.kts`

**Tasks:**
- [ ] Set `compileSdk = 34`
- [ ] Set `minSdk = 21`
- [ ] Set `targetSdk = 34`
- [ ] Set `namespace = "com.repsync.app"`
- [ ] Update application ID
- [ ] Test build

**Acceptance Criteria:**
- [ ] All SDK versions set
- [ ] Namespace configured
- [ ] Build succeeds

**Definition of Done:**
- [ ] Config updated
- [ ] Build passing

---

### P0-AND-02: Configure Release Signing
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Android
- **Files:** `android/app/build.gradle.kts`, keystore

**Tasks:**
- [ ] Generate keystore
- [ ] Configure signing config
- [ ] Add to gradle.properties
- [ ] Add to CI secrets
- [ ] Test release build
- [ ] Document signing process

**Acceptance Criteria:**
- [ ] Release signing configured
- [ ] Build succeeds
- [ ] Secrets secured

**Definition of Done:**
- [ ] Signing configured
- [ ] Documented

---

### P0-AND-03: Add ProGuard Rules
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Android
- **Files:** `proguard-rules.pro`, `build.gradle.kts`

**Tasks:**
- [ ] Create `proguard-rules.pro`
- [ ] Add Flutter rules
- [ ] Add Firebase rules
- [ ] Add Hive rules
- [ ] Enable minification
- [ ] Enable resource shrinking
- [ ] Test release build
- [ ] Verify APK size reduction

**Acceptance Criteria:**
- [ ] ProGuard configured
- [ ] APK < 30MB
- [ ] App works correctly

**Definition of Done:**
- [ ] Rules created
- [ ] Build optimized

---

### P0-AND-04: Add Storage Permissions
- **Estimate:** 30 min
- **Priority:** P0 🔴
- **Category:** Android
- **File:** `AndroidManifest.xml`

**Tasks:**
- [ ] Add READ_EXTERNAL_STORAGE
- [ ] Add WRITE_EXTERNAL_STORAGE
- [ ] Add conditional for Android 13+
- [ ] Test on Android 9, 10, 13

**Acceptance Criteria:**
- [ ] Permissions declared
- [ ] Works on all versions

**Definition of Done:**
- [ ] Manifest updated
- [ ] Tested

---

### P0-AND-05: Add Notification Permission
- **Estimate:** 30 min
- **Priority:** P0 🔴
- **Category:** Android
- **File:** `AndroidManifest.xml`

**Tasks:**
- [ ] Add POST_NOTIFICATIONS
- [ ] Add runtime request
- [ ] Test on Android 13+

**Acceptance Criteria:**
- [ ] Permission declared
- [ ] Runtime request works

**Definition of Done:**
- [ ] Manifest updated
- [ ] Tested

---

### P0-AND-06: Configure Build Flavors
- **Estimate:** 3 hours
- **Priority:** P0 🔴
- **Category:** Android
- **Files:** `build.gradle.kts`, `main.dart`

**Tasks:**
- [ ] Define dev flavor
- [ ] Define staging flavor
- [ ] Define production flavor
- [ ] Configure different app IDs
- [ ] Configure different Firebase configs
- [ ] Add flavor to CI
- [ ] Test each flavor

**Acceptance Criteria:**
- [ ] All flavors build
- [ ] Different configs work
- [ ] CI builds all flavors

**Definition of Done:**
- [ ] Flavors configured
- [ ] All build
- [ ] CI updated

---

### P0-AND-07: Add Deep Linking (Android)
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Android
- **File:** `AndroidManifest.xml`

**Tasks:**
- [ ] Add intent filters
- [ ] Configure URL handling
- [ ] Test deep links
- [ ] Test app links

**Acceptance Criteria:**
- [ ] Deep links work
- [ ] App links verified

**Definition of Done:**
- [ ] Manifest updated
- [ ] Tested

---

### P0-AND-08: Add Share Intents
- **Estimate:** 2 hours
- **Priority:** P0 🔴
- **Category:** Android
- **File:** `AndroidManifest.xml`

**Tasks:**
- [ ] Add share intent filter
- [ ] Handle incoming shares
- [ ] Test share flow
- [ ] Document usage

**Acceptance Criteria:**
- [ ] Share intents work
- [ ] App appears in share menu

**Definition of Done:**
- [ ] Manifest updated
- [ ] Tested

---

### P0-AND-09: Branded Splash Screen
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Android
- **Files:** `android/app/src/main/res/`

**Tasks:**
- [ ] Create splash screen drawable
- [ ] Add RepSync logo
- [ ] Configure theme
- [ ] Test on cold start
- [ ] Test on different screen sizes

**Acceptance Criteria:**
- [ ] Branded splash shows
- [ ] No white flash
- [ ] Looks professional

**Definition of Done:**
- [ ] Splash created
- [ ] Tested

---

### P0-AND-10: Test on Android 10, 12, 13, 14
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Testing
- **Devices:** Emulators/Physical

**Tasks:**
- [ ] Test on Android 10
- [ ] Test on Android 12
- [ ] Test on Android 13
- [ ] Test on Android 14
- [ ] Document issues
- [ ] Fix compatibility issues

**Acceptance Criteria:**
- [ ] All versions tested
- [ ] No critical issues
- [ ] Documented

**Definition of Done:**
- [ ] Testing complete
- [ ] Issues fixed

---

## 🎨 UI/UX IMPROVEMENTS (16 hours)

### P1-UX-01: Add Semantics Widgets
- **Estimate:** 3 hours
- **Priority:** P1 🟠
- **Category:** Accessibility
- **Files:** Multiple screen files

**Tasks:**
- [ ] Audit screens for accessibility
- [ ] Add Semantics to buttons
- [ ] Add Semantics to images
- [ ] Add labels to form fields
- [ ] Add live regions for dynamic content
- [ ] Test with screen reader

**Acceptance Criteria:**
- [ ] All interactive elements labeled
- [ ] Screen reader works
- [ ] WCAG 2.1 AA compliant

**Definition of Done:**
- [ ] Semantics added
- [ ] Tested with screen reader

---

### P1-UX-02: Fix Color Contrast
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Accessibility
- **Files:** Theme files, widgets

**Tasks:**
- [ ] Audit all colors with WCAG checker
- [ ] Replace `Colors.grey` with accessible colors
- [ ] Replace `Colors.blue` with brand orange
- [ ] Update theme colors
- [ ] Test contrast ratios
- [ ] Document color system

**Acceptance Criteria:**
- [ ] All text 4.5:1 contrast
- [ ] All UI elements 3:1 contrast
- [ ] WCAG AA compliant

**Definition of Done:**
- [ ] Colors fixed
- [ ] Verified with checker

---

### P1-UX-03: Add Text Scaling Support
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Accessibility
- **Files:** Multiple widget files

**Tasks:**
- [ ] Use MediaQuery.textScaler
- [ ] Test with large text
- [ ] Test with small text
- [ ] Fix overflow issues
- [ ] Test on all screens

**Acceptance Criteria:**
- [ ] Scales 0.8x to 2.0x
- [ ] No overflow
- [ ] Readable at all sizes

**Definition of Done:**
- [ ] Scaling implemented
- [ ] Tested

---

### P1-UX-04: Add Tablet Layouts
- **Estimate:** 4 hours
- **Priority:** P1 🟠
- **Category:** Responsive Design
- **Files:** Screen files

**Tasks:**
- [ ] Add breakpoint detection
- [ ] Create tablet layouts for home
- [ ] Create tablet layouts for songs
- [ ] Create tablet layouts for bands
- [ ] Create tablet layouts for setlists
- [ ] Test on 7", 10", 12" tablets

**Acceptance Criteria:**
- [ ] Tablet layouts exist
- [ ] Screen space used well
- [ ] No wasted space

**Definition of Done:**
- [ ] Layouts created
- [ ] Tested on tablets

---

### P1-UX-05: Add Keyboard Navigation (Web)
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Accessibility
- **Files:** Multiple files

**Tasks:**
- [ ] Add Focus nodes
- [ ] Add keyboard shortcuts
- [ ] Add Tab navigation
- [ ] Add Enter to submit
- [ ] Add Escape to cancel
- [ ] Test on web

**Acceptance Criteria:**
- [ ] All actions keyboard accessible
- [ ] Tab order logical
- [ ] Shortcuts work

**Definition of Done:**
- [ ] Navigation added
- [ ] Tested on web

---

### P1-UX-06: Fix Hardcoded Colors
- **Estimate:** 1 hour
- **Priority:** P2 🟡
- **Category:** Design System
- **Files:** Widget files

**Tasks:**
- [ ] Find all hardcoded colors
- [ ] Replace with theme colors
- [ ] Update SongBPMBadge to orange
- [ ] Update empty state colors
- [ ] Run analyzer

**Acceptance Criteria:**
- [ ] No hardcoded colors
- [ ] All use theme
- [ ] Consistent branding

**Definition of Done:**
- [ ] Colors fixed
- [ ] Analyzer clean

---

### P1-UX-07: Add Missing Error States
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** UX
- **Files:** Screen files

**Tasks:**
- [ ] Add PDF export error state
- [ ] Add image upload error state
- [ ] Add sync error state
- [ ] Add API error states
- [ ] Design error UI
- [ ] Implement retry actions

**Acceptance Criteria:**
- [ ] All error states covered
- [ ] User-friendly messages
- [ ] Retry actions work

**Definition of Done:**
- [ ] Error states added
- [ ] Tested

---

### P1-UX-08: UX Review & Documentation
- **Estimate:** 2 hours
- **Priority:** P2 🟡
- **Category:** Documentation
- **Files:** `docs/UX_GUIDELINES.md`

**Tasks:**
- [ ] Document design system
- [ ] Document accessibility guidelines
- [ ] Document responsive breakpoints
- [ ] Document color usage
- [ ] Add to PROJECT.md

**Acceptance Criteria:**
- [ ] Documentation complete
- [ ] Team can reference

**Definition of Done:**
- [ ] Documentation written
- [ ] Committed

---

## 📊 LOGGING & MONITORING (8 hours)

### P1-MON-01: Add Firebase Crashlytics
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Monitoring
- **Files:** `pubspec.yaml`, `main.dart`

**Tasks:**
- [ ] Add firebase_crashlytics dependency
- [ ] Initialize Crashlytics in main
- [ ] Configure for dev vs prod
- [ ] Set custom keys (version, environment)
- [ ] Test crash reporting
- [ ] Document dashboard

**Acceptance Criteria:**
- [ ] Crashlytics initialized
- [ ] Crashes reported
- [ ] Dev crashes filtered

**Definition of Done:**
- [ ] Integrated
- [ ] Tested
- [ ] Documented

---

### P1-MON-02: Add HTTP Logging Interceptor
- **Estimate:** 1 hour
- **Priority:** P1 🟠
- **Category:** Monitoring
- **Files:** `lib/services/http_interceptor.dart`

**Tasks:**
- [ ] Create HTTP interceptor
- [ ] Log requests
- [ ] Log responses
- [ ] Log errors
- [ ] Add to all HTTP clients
- [ ] Guard for debug mode

**Acceptance Criteria:**
- [ ] All HTTP logged
- [ ] Debug-only
- [ ] No sensitive data

**Definition of Done:**
- [ ] Interceptor created
- [ ] Integrated

---

### P1-MON-03: Create Debug Screen
- **Estimate:** 2 hours
- **Priority:** P1 🟠
- **Category:** Debugging
- **Files:** `lib/screens/debug_screen.dart`

**Tasks:**
- [ ] Create debug screen
- [ ] Show log history
- [ ] Show error history
- [ ] Show app info
- [ ] Show connectivity status
- [ ] Add clear logs button
- [ ] Add export logs button
- [ ] Guard for debug mode

**Acceptance Criteria:**
- [ ] Debug screen functional
- [ ] Logs visible
- [ ] Export works
- [ ] Debug-only

**Definition of Done:**
- [ ] Screen created
- [ ] Integrated in dev

---

### P1-MON-04: Add Performance Monitoring
- **Estimate:** 30 min
- **Priority:** P2 🟡
- **Category:** Monitoring
- **Files:** `main.dart`, Firebase

**Tasks:**
- [ ] Add firebase_performance dependency
- [ ] Initialize Performance
- [ ] Enable automatic screen traces
- [ ] Configure for prod only
- [ ] Document dashboard

**Acceptance Criteria:**
- [ ] Performance monitoring active
- [ ] Screen traces collected
- [ ] Prod-only

**Definition of Done:**
- [ ] Integrated
- [ ] Documented

---

### P1-MON-05: Document Logging Conventions
- **Estimate:** 30 min
- **Priority:** P2 🟡
- **Category:** Documentation
- **Files:** `docs/LOGGING.md`

**Tasks:**
- [ ] Document log levels
- [ ] Document when to use each level
- [ ] Document sensitive data rules
- [ ] Document production logging
- [ ] Add examples

**Acceptance Criteria:**
- [ ] Conventions documented
- [ ] Examples provided

**Definition of Done:**
- [ ] Documentation written
- [ ] Committed

---

## 📋 SPRINT 4 CHECKLIST

### Android Production
- [ ] P0-AND-01: SDK versions
- [ ] P0-AND-02: Release signing
- [ ] P0-AND-03: ProGuard rules
- [ ] P0-AND-04: Storage permissions
- [ ] P0-AND-05: Notification permission
- [ ] P0-AND-06: Build flavors
- [ ] P0-AND-07: Deep linking
- [ ] P0-AND-08: Share intents
- [ ] P0-AND-09: Branded splash
- [ ] P0-AND-10: Multi-version testing

### UI/UX Improvements
- [ ] P1-UX-01: Semantics widgets
- [ ] P1-UX-02: Color contrast
- [ ] P1-UX-03: Text scaling
- [ ] P1-UX-04: Tablet layouts
- [ ] P1-UX-05: Keyboard navigation
- [ ] P1-UX-06: Hardcoded colors
- [ ] P1-UX-07: Error states
- [ ] P1-UX-08: UX documentation

### Logging & Monitoring
- [ ] P1-MON-01: Firebase Crashlytics
- [ ] P1-MON-02: HTTP interceptor
- [ ] P1-MON-03: Debug screen
- [ ] P1-MON-04: Performance monitoring
- [ ] P1-MON-05: Logging documentation

---

## 📊 SPRINT 4 SUCCESS METRICS

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Android Score | 5.5/10 | 8.5/10 | ⬜ |
| UX Score | 7.2/10 | 8.5/10 | ⬜ |
| Logging Score | 4.2/10 | 8.0/10 | ⬜ |
| Test Coverage | 75% | 80%+ | ⬜ |
| Production Ready | No | Yes | ⬜ |
| v1.0.0 Released | No | Yes | ⬜ |

---

## 🔄 SPRINT 4 REVIEW & RETROSPECTIVE

### Sprint Review (March 25, 2026)

**Demo Items:**
- [ ] Android production build
- [ ] UI/UX improvements
- [ ] Crashlytics dashboard
- [ ] Debug screen
- [ ] v1.0.0 release candidate

**Stakeholders:**
- [ ] Product Owner
- [ ] Development Team
- [ ] UX Reviewer
- [ ] Release Manager

### Sprint Retrospective

**What Went Well:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**What Could Be Improved:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

**Action Items for Future Sprints:**
- [ ] _Team to fill in_
- [ ] _Team to fill in_

---

# 📈 OVERALL PROJECT METRICS

## Final Success Criteria

| Category | Initial | Week 1 | Week 2 | Week 3 | Week 4 Target |
|----------|---------|--------|--------|--------|---------------|
| **Overall Score** | 5.4/10 | 6.0/10 | 6.8/10 | 7.5/10 | **8.0/10** |
| **Security** | 4.0/10 | 9.0/10 | 9.0/10 | 9.0/10 | **9.0/10** |
| **Test Coverage** | 39.8% | 50% | 65% | 75% | **80%+** |
| **Test Pass Rate** | 76.6% | 100% | 100% | 100% | **100%** |
| **Critical Issues** | 12 | 0 | 0 | 0 | **0** |
| **Memory Leaks** | 5+ | 0 | 0 | 0 | **0** |
| **CI/CD** | None | Basic | Enhanced | Full | **Full Pipeline** |
| **Android Score** | 5.5/10 | 6.5/10 | 7.0/10 | 7.5/10 | **8.5/10** |
| **UX Score** | 7.2/10 | 7.2/10 | 7.5/10 | 8.0/10 | **8.5/10** |
| **Logging Score** | 4.2/10 | 5.0/10 | 6.0/10 | 7.0/10 | **8.0/10** |

---

## Release Checklist

### v0.12.0 (End of Sprint 1)
- [ ] All P0 security fixes complete
- [ ] All memory leaks fixed
- [ ] Tests passing 100%
- [ ] CI pipeline running
- [ ] LoggerService integrated

### v0.13.0 (End of Sprint 2)
- [ ] Repository pattern implemented
- [ ] GoRouter migration complete
- [ ] Deep linking working
- [ ] Code quality issues resolved
- [ ] Analyzer clean

### v0.14.0 (End of Sprint 3)
- [ ] 75%+ test coverage
- [ ] All service tests passing
- [ ] All provider tests passing
- [ ] Integration tests passing
- [ ] Coverage enforced in CI

### v1.0.0 (End of Sprint 4)
- [ ] Android production ready
- [ ] All SDK versions set
- [ ] Release signing configured
- [ ] ProGuard optimized
- [ ] Build flavors working
- [ ] UI/UX improvements complete
- [ ] Accessibility compliant
- [ ] Crashlytics integrated
- [ ] Performance monitoring active
- [ ] 80%+ test coverage
- [ ] All audits passed

---

**Document Created:** February 25, 2026
**Last Updated:** February 25, 2026
**Next Review:** March 25, 2026
