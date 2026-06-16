# 🧪 MrTester - Sprint 3 Task Assignment

**Sprint:** 3 - Testing & QA  
**Agent:** MrTester (Primary)  
**Total Allocation:** 38 hours  
**Status:** 🟡 In Progress  

---

## 📋 Your Tasks

### Day 1-2: Service Tests (16 hours)

#### Task 1: P0-SVC-01 - Spotify Service Tests
- **File:** `test/services/spotify_service_test.dart`
- **Estimate:** 4 hours
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock HTTP client for Spotify API calls
- [ ] Test token exchange flow
- [ ] Test track analysis (BPM, key detection)
- [ ] Test error handling (network failures, rate limits)
- [ ] Test rate limiting behavior
- [ ] Achieve 80%+ coverage

**Acceptance Criteria:**
- All SpotifyService methods tested
- Error cases covered with proper exceptions
- 80%+ line coverage
- All tests passing

---

#### Task 2: P0-SVC-02 - MusicBrainz Service Tests
- **File:** `test/services/musicbrainz_service_test.dart`
- **Estimate:** 3 hours
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock HTTP client for MusicBrainz API
- [ ] Test search functionality (by title, artist)
- [ ] Test metadata retrieval
- [ ] Test error handling
- [ ] Test caching behavior
- [ ] Achieve 80%+ coverage

---

#### Task 3: P0-SVC-03 - Track Analysis Service Tests
- **File:** `test/services/track_analysis_service_test.dart`
- **Estimate:** 2 hours
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock SpotifyService dependency
- [ ] Test full analysis flow
- [ ] Test result parsing and normalization
- [ ] Test error handling
- [ ] Achieve 80%+ coverage

---

#### Task 4: P0-SVC-04 - PDF Export Service Tests
- **File:** `test/services/pdf_service_test.dart`
- **Estimate:** 2 hours
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock PDF generation dependencies
- [ ] Test setlist rendering
- [ ] Test formatting (fonts, spacing)
- [ ] Test error handling
- [ ] Add golden tests for PDF output samples
- [ ] Achieve 80%+ coverage

---

#### Task 5: P0-SVC-05 - Audio Service Tests
- **File:** `test/services/audio_service_test.dart`
- **Estimate:** 2 hours
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock audio platform interface
- [ ] Test playback controls (play, pause, stop)
- [ ] Test volume control
- [ ] Test error handling
- [ ] Achieve 80%+ coverage

---

#### Task 6: P0-SVC-06 - Cache Service Tests
- **File:** `test/services/cache_service_test.dart`
- **Estimate:** 2 hours
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock Hive database
- [ ] Test cache write operations
- [ ] Test cache read operations
- [ ] Test cache invalidation
- [ ] Test TTL (time-to-live) expiration
- [ ] Achieve 80%+ coverage

---

#### Task 7: P0-SVC-07 - Connectivity Service Tests
- **File:** `test/services/connectivity_service_test.dart`
- **Estimate:** 1 hour
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock connectivity plugin
- [ ] Test online detection
- [ ] Test offline detection
- [ ] Test connectivity stream
- [ ] Test dispose pattern (no memory leaks)
- [ ] Achieve 80%+ coverage

---

#### Task 8: P0-SVC-08 - Firestore Service Tests
- **File:** `test/services/firestore_service_test.dart`
- **Estimate:** 3 hours
- **Priority:** P0 🔴

**Requirements:**
- [ ] Mock Firestore instance
- [ ] Test CRUD operations for all collections
- [ ] Test query methods
- [ ] Test stream subscriptions
- [ ] Test error handling
- [ ] Test security (auth checks)
- [ ] Achieve 80%+ coverage

---

### Day 3-4: Provider Tests (16 hours)

#### Task 9: P0-SVC-12 - Auth Provider Tests
- **File:** `test/providers/auth_provider_test.dart`
- **Estimate:** 3 hours
- **Priority:** P1 🟠

**Requirements:**
- [ ] Mock Firebase Auth
- [ ] Test sign in flow
- [ ] Test sign up flow
- [ ] Test sign out
- [ ] Test password reset
- [ ] Test Google sign in
- [ ] Test error handling
- [ ] Achieve 85%+ coverage

---

#### Task 10: P0-SVC-11 - Error Provider Tests
- **File:** `test/providers/error_provider_test.dart`
- **Estimate:** 2 hours
- **Priority:** P1 🟠

**Requirements:**
- [ ] Test error handling
- [ ] Test error state management
- [ ] Test error history
- [ ] Test clear functionality
- [ ] Achieve 85%+ coverage

---

#### Task 11: P0-SVC-09 - CSV Service Tests
- **File:** `test/services/csv_service_test.dart`
- **Estimate:** 1 hour
- **Priority:** P1 🟠

**Requirements:**
- [ ] Test CSV export functionality
- [ ] Test CSV import parsing
- [ ] Test error handling (malformed CSV)
- [ ] Achieve 80%+ coverage

---

#### Task 12: P0-SVC-10 - Logger Service Tests
- **File:** `test/services/logger_service_test.dart`
- **Estimate:** 1 hour
- **Priority:** P1 🟠

**Requirements:**
- [ ] Test all log levels (verbose, debug, info, warning, error, fatal)
- [ ] Test log history
- [ ] Test filtering by level
- [ ] Test log export
- [ ] Test configuration
- [ ] Achieve 80%+ coverage

---

#### Task 13: P1-PRV-01 - Data Provider Tests
- **File:** `test/providers/data_providers_test.dart`
- **Estimate:** 4 hours
- **Priority:** P1 🟠

**Requirements:**
- [ ] Mock all repositories (Song, Band, Setlist)
- [ ] Test bands provider streams
- [ ] Test songs provider streams
- [ ] Test setlists provider streams
- [ ] Test error handling
- [ ] Achieve 85%+ coverage

---

#### Task 14: P1-PRV-02 - Metronome Provider Tests
- **File:** `test/providers/metronome_provider_test.dart`
- **Estimate:** 3 hours
- **Priority:** P1 🟠

**Requirements:**
- [ ] Test state changes (start, stop, pause)
- [ ] Test BPM changes
- [ ] Test time signature changes
- [ ] Test accent patterns
- [ ] Test preset management
- [ ] Achieve 85%+ coverage

---

#### Task 15: P1-PRV-03 - Tuner Provider Tests
- **File:** `test/providers/tuner_provider_test.dart`
- **Estimate:** 2 hours
- **Priority:** P1 🟠

**Requirements:**
- [ ] Mock audio input
- [ ] Test pitch detection
- [ ] Test note calculation
- [ ] Test cents offset
- [ ] Achieve 85%+ coverage

---

#### Task 16: P1-PRV-04 - UI Provider Tests
- **File:** `test/providers/ui_providers_test.dart`
- **Estimate:** 2 hours
- **Priority:** P1 🟠

**Requirements:**
- [ ] Test theme provider (light/dark mode)
- [ ] Test loading states
- [ ] Test dialog states
- [ ] Test snackbar states
- [ ] Achieve 85%+ coverage

---

### Day 5: Integration Tests (8 hours)

#### Task 17: P2-INT-01 - Song Creation Flow
- **File:** `test/integration/song_creation_test.dart`
- **Estimate:** 2 hours
- **Priority:** P2 🟡

**Requirements:**
- [ ] Navigate to add song screen
- [ ] Fill song form (title, artist, key, BPM)
- [ ] Save song
- [ ] Verify appears in song list
- [ ] Test edit functionality
- [ ] Test delete functionality

---

#### Task 18: P2-INT-02 - Band Management Flow
- **File:** `test/integration/band_management_test.dart`
- **Estimate:** 2 hours
- **Priority:** P2 🟡

**Requirements:**
- [ ] Create new band
- [ ] Generate invite code
- [ ] Join band (second user)
- [ ] Manage members (promote, remove)
- [ ] Test role permissions
- [ ] Test access control

---

#### Task 19: P2-INT-03 - Setlist Creation Flow
- **File:** `test/integration/setlist_creation_test.dart`
- **Estimate:** 2 hours
- **Priority:** P2 🟡

**Requirements:**
- [ ] Create new setlist
- [ ] Add songs to setlist
- [ ] Reorder songs
- [ ] Calculate total duration
- [ ] Export to PDF
- [ ] Share setlist

---

#### Task 20: P2-INT-04 - User Authentication Flow
- **File:** `test/integration/auth_flow_test.dart`
- **Estimate:** 1 hour
- **Priority:** P2 🟡

**Requirements:**
- [ ] Register new user
- [ ] Verify email flow
- [ ] Sign in existing user
- [ ] Sign out
- [ ] Password reset flow
- [ ] Google sign in flow

---

#### Task 21: P2-INT-05 - Offline Sync Flow
- **File:** `test/integration/offline_sync_test.dart`
- **Estimate:** 2 hours
- **Priority:** P2 🟡

**Requirements:**
- [ ] Go offline (simulate no connectivity)
- [ ] Create/edit data offline
- [ ] Verify data cached locally
- [ ] Go online
- [ ] Verify data synced to Firestore
- [ ] Test conflict resolution

---

## 📊 Progress Tracking

| Task | Status | Hours Spent | Coverage Achieved |
|------|--------|-------------|-------------------|
| P0-SVC-01 | ⬜ Pending | 0h | - |
| P0-SVC-02 | ⬜ Pending | 0h | - |
| P0-SVC-03 | ⬜ Pending | 0h | - |
| P0-SVC-04 | ⬜ Pending | 0h | - |
| P0-SVC-05 | ⬜ Pending | 0h | - |
| P0-SVC-06 | ⬜ Pending | 0h | - |
| P0-SVC-07 | ⬜ Pending | 0h | - |
| P0-SVC-08 | ⬜ Pending | 0h | - |
| P0-SVC-09 | ⬜ Pending | 0h | - |
| P0-SVC-10 | ⬜ Pending | 0h | - |
| P0-SVC-11 | ⬜ Pending | 0h | - |
| P0-SVC-12 | ⬜ Pending | 0h | - |
| P1-PRV-01 | ⬜ Pending | 0h | - |
| P1-PRV-02 | ⬜ Pending | 0h | - |
| P1-PRV-03 | ⬜ Pending | 0h | - |
| P1-PRV-04 | ⬜ Pending | 0h | - |
| P2-INT-01 | ⬜ Pending | 0h | - |
| P2-INT-02 | ⬜ Pending | 0h | - |
| P2-INT-03 | ⬜ Pending | 0h | - |
| P2-INT-04 | ⬜ Pending | 0h | - |
| P2-INT-05 | ⬜ Pending | 0h | - |

**Total:** 0/21 tasks complete | **Hours:** 0h / 38h

---

## 🎯 Quality Standards

1. **Coverage:** Minimum 80% for services, 85% for providers
2. **Mocking:** Use `mockito` for all external dependencies
3. **Naming:** Follow pattern `<component>_test.dart`
4. **Structure:** Arrange-Act-Assert pattern
5. **Documentation:** Comment complex test scenarios

---

## 📞 Escalation

If you encounter:
- Complex mocking scenarios → Consult MrSeniorDeveloper
- Test flakiness → Document and flag
- Coverage blockers → Report to MrSync

---

**Start Date:** March 11, 2026  
**Target Completion:** March 15, 2026
