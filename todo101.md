# RepSync Project - Improvement Tasks (TODO-101)

**Created:** February 19, 2026  
**Source:** report101.md  
**Total Tasks:** 22  
**Estimated Total Effort:** 226 hours

---

## Task Status Legend

| Status | Icon | Description |
|--------|------|-------------|
| Pending | ⬜ | Not started |
| In Progress | 🔄 | Currently working |
| Completed | ✅ | Finished |
| Blocked | 🚫 | Cannot proceed |
| Deferred | ⏸️ | Postponed |

---

## Phase 0: Critical Security & Quality (Week 1)

**Goal:** Address critical security vulnerabilities and code quality issues

### Task 0.1: Move Spotify API Keys to Environment Variables
- **ID:** TODO-101-0.1
- **Status:** ✅ Completed
- **Priority:** 🔴 CRITICAL
- **Estimated Effort:** 2 hours
- **Category:** Security
- **Files to Modify:**
  - `pubspec.yaml` (add flutter_dotenv)
  - `lib/services/spotify_service.dart`
  - `.env` (create)
  - `.gitignore` (update)
- **Implementation Steps:**
  1. Add `flutter_dotenv: ^5.1.0` to pubspec.yaml dependencies
  2. Create `.env` file with SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET
  3. Add `.env` to `.gitignore`
  4. Update `spotify_service.dart` to use `dotenv.env['SPOTIFY_CLIENT_ID']`
  5. Update initialization in `main.dart` to load dotenv
  6. Create `.env.example` for documentation
  7. Test Spotify integration
- **Acceptance Criteria:**
  - [ ] No hardcoded credentials in source code
  - [ ] `.env` file is gitignored
  - [ ] Spotify integration works with environment variables
  - [ ] Documentation updated
- **Dependencies:** None
- **Risk:** Low

---

### Task 0.2: Document and Implement Firestore Security Rules
- **ID:** TODO-101-0.2
- **Status:** ✅ Completed
- **Priority:** 🔴 CRITICAL
- **Estimated Effort:** 4 hours
- **Category:** Security
- **Files to Create/Modify:**
  - `firestore.rules` (create)
  - `README.md` (update)
  - Firebase Console (deploy)
- **Implementation Steps:**
  1. Create `firestore.rules` with proper access control
  2. Document rules in README.md
  3. Deploy rules to Firebase using Firebase CLI
  4. Test rules with Firebase Emulator Suite
  5. Create test cases for rule validation
- **Acceptance Criteria:**
  - [ ] `firestore.rules` file exists
  - [ ] Rules prevent unauthorized access
  - [ ] Rules documented in README
  - [ ] Rules deployed to Firebase
  - [ ] Test cases pass
- **Dependencies:** None
- **Risk:** Medium

---

### Task 0.3: Enable Stricter Linting Rules
- **ID:** TODO-101-0.3
- **Status:** ✅ Completed
- **Priority:** 🟠 HIGH
- **Estimated Effort:** 4 hours
- **Category:** Code Quality
- **Files to Modify:**
  - `analysis_options.yaml`
  - Various Dart files (to fix violations)
- **Implementation Steps:**
  1. Update `analysis_options.yaml` with stricter rules
  2. Run `flutter analyze` to identify violations
  3. Fix all linting violations
  4. Add linting to CI/CD workflow
- **Lint Rules to Add:**
  ```yaml
  linter:
    rules:
      - prefer_const_constructors
      - prefer_const_literals_to_create_immutables
      - prefer_single_quotes
      - require_trailing_commas
      - avoid_print
      - avoid_unnecessary_containers
      - prefer_is_empty
      - prefer_is_not_empty
      - sort_pub_dependencies
      - organize_imports
      - public_member_api_docs
      - lines_longer_than_80_chars
  ```
- **Acceptance Criteria:**
  - [ ] All new lint rules enabled
  - [ ] Zero linting violations
  - [ ] Code formatted consistently
- **Dependencies:** None
- **Risk:** Low

---

## Phase 1: Code Quality & Testing (Weeks 2-3)

**Goal:** Improve code maintainability and add comprehensive test coverage

### Task 1.1: Refactor add_song_screen.dart
- **ID:** TODO-101-1.1
- **Status:** ✅ Completed
- **Priority:** 🔴 CRITICAL
- **Estimated Effort:** 8 hours
- **Category:** Code Quality / Refactoring
- **Files to Create/Modify:**
  - `lib/screens/songs/add_song_screen.dart` (reduce to ~200 lines)
  - `lib/screens/songs/components/` (create directory)
  - `song_form.dart` (create)
  - `spotify_search_section.dart` (create)
  - `musicbrainz_search_section.dart` (create)
  - `key_selector.dart` (create)
  - `bpm_selector.dart` (create)
  - `links_editor.dart` (create)
- **Implementation Steps:**
  1. Create `components/` directory
  2. Extract song form widget to `song_form.dart`
  3. Extract Spotify search to `spotify_search_section.dart`
  4. Extract MusicBrainz search to `musicbrainz_search_section.dart`
  5. Extract key selector to `key_selector.dart`
  6. Extract BPM selector to `bpm_selector.dart`
  7. Extract links editor to `links_editor.dart`
  8. Update imports in `add_song_screen.dart`
  9. Test all functionality
- **Acceptance Criteria:**
  - [ ] `add_song_screen.dart` < 300 lines
  - [ ] All components are reusable
  - [ ] All functionality preserved
  - [ ] No regression in tests
- **Dependencies:** None
- **Risk:** Medium

---

### Task 1.2: Add Model Unit Tests
- **ID:** TODO-101-1.2
- **Status:** ✅ Completed
- **Priority:** 🔴 CRITICAL
- **Estimated Effort:** 4 hours
- **Category:** Testing
- **Files to Create:**
  - `test/models/song_test.dart`
  - `test/models/band_test.dart`
  - `test/models/setlist_test.dart`
  - `test/models/link_test.dart`
  - `test/models/user_test.dart`
- **Implementation Steps:**
  1. Create test directory structure
  2. Write tests for `Song.fromJson()` and `toJson()`
  3. Write tests for `Song.copyWith()`
  4. Repeat for all models
  5. Add edge case tests
  6. Run tests and ensure 100% pass
- **Test Coverage Goals:**
  - [ ] `fromJson` parsing
  - [ ] `toJson` serialization
  - [ ] `copyWith` modifications
  - [ ] Null handling
  - [ ] Default values
- **Acceptance Criteria:**
  - [ ] All models have unit tests
  - [ ] Test coverage > 90% for models
  - [ ] All tests pass
- **Dependencies:** None
- **Risk:** Low

---

### Task 1.3: Add Provider Unit Tests
- **ID:** TODO-101-1.3
- **Status:** ✅ Completed
- **Priority:** 🔴 CRITICAL
- **Estimated Effort:** 8 hours
- **Category:** Testing
- **Files to Create:**
  - `test/providers/auth_provider_test.dart`
  - `test/providers/data_providers_test.dart`
- **Dependencies:** 
  - `mockito: ^6.0.0` (add to dev_dependencies)
  - `mocktail: ^1.0.0` (for Riverpod mocking)
- **Implementation Steps:**
  1. Add mockito and mocktail to pubspec.yaml
  2. Create mocks for Firebase services
  3. Test `AppUserNotifier` state transitions
  4. Test `SelectedBandNotifier`
  5. Test `BottomNavIndexNotifier`
  6. Test StreamProviders with mock streams
- **Test Coverage Goals:**
  - [ ] Provider initialization
  - [ ] State updates
  - [ ] Error handling
  - [ ] Loading states
- **Acceptance Criteria:**
  - [ ] All providers tested
  - [ ] Test coverage > 80% for providers
  - [ ] All tests pass
- **Dependencies:** Task 1.2 (model tests as examples)
- **Risk:** Medium

---

### Task 1.4: Add Widget Tests
- **ID:** TODO-101-1.4
- **Status:** ✅ Completed
- **Priority:** 🔴 CRITICAL
- **Estimated Effort:** 16 hours
- **Category:** Testing
- **Files to Create:**
  - `test/screens/login_screen_test.dart`
  - `test/screens/register_screen_test.dart`
  - `test/screens/home_screen_test.dart`
  - `test/screens/songs_list_screen_test.dart`
  - `test/screens/add_song_screen_test.dart`
  - `test/screens/bands_screen_test.dart`
  - `test/screens/setlists_screen_test.dart`
  - `test/widgets/custom_button_test.dart` (after Task 1.6)
- **Implementation Steps:**
  1. Set up test utilities and helpers
  2. Create ProviderContainer for tests
  3. Write rendering tests for each screen
  4. Write interaction tests (button taps, form input)
  5. Write error state tests
  6. Write loading state tests
- **Test Coverage Goals:**
  - [ ] Screen renders without errors
  - [ ] All user interactions work
  - [ ] Error states display correctly
  - [ ] Loading states display correctly
- **Acceptance Criteria:**
  - [ ] All screens have widget tests
  - [ ] Test coverage > 60% for screens
  - [ ] All tests pass
- **Dependencies:** Task 1.2, 1.3
- **Risk:** Medium

---

### Task 1.5: Add Integration Tests
- **ID:** TODO-101-1.5
- **Status:** ✅ Completed
- **Priority:** 🟠 HIGH
- **Estimated Effort:** 12 hours
- **Category:** Testing
- **Files to Create:**
  - `test/integration/firestore_integration_test.dart`
  - `test/integration/auth_integration_test.dart`
  - `test/integration/api_integration_test.dart`
- **Dependencies:** 
  - `integration_test` package
  - Firebase Emulator Suite
- **Implementation Steps:**
  1. Add integration_test package
  2. Set up Firebase Emulator
  3. Write Firestore CRUD tests
  4. Write authentication flow tests
  5. Write API integration tests (Spotify, MusicBrainz)
  6. Run tests on CI
- **Acceptance Criteria:**
  - [ ] Integration tests run successfully
  - [ ] Firebase Emulator configured
  - [ ] CI/CD runs integration tests
- **Dependencies:** Task 1.2, 1.3, 1.4
- **Risk:** High

---

### Task 1.6: Populate widgets/ Directory
- **ID:** TODO-101-1.6
- **Status:** ✅ Completed
- **Priority:** 🟠 HIGH
- **Estimated Effort:** 12 hours
- **Category:** Architecture / Reusability
- **Files to Create:**
  - `lib/widgets/custom_button.dart`
  - `lib/widgets/custom_text_field.dart`
  - `lib/widgets/loading_indicator.dart`
  - `lib/widgets/error_banner.dart`
  - `lib/widgets/song_card.dart`
  - `lib/widgets/band_card.dart`
  - `lib/widgets/setlist_card.dart`
  - `lib/widgets/confirmation_dialog.dart`
  - `lib/widgets/link_chip.dart`
  - `lib/widgets/empty_state.dart`
- **Implementation Steps:**
  1. Create each widget file
  2. Implement consistent styling
  3. Add documentation
  4. Update screens to use new widgets
  5. Write widget tests
- **Acceptance Criteria:**
  - [ ] All 10 widgets created
  - [ ] Widgets used in screens
  - [ ] Widgets documented
  - [ ] Widgets tested
- **Dependencies:** None
- **Risk:** Low

---

### Task 1.7: Complete Search Functionality
- **ID:** TODO-101-1.7
- **Status:** ✅ Completed
- **Priority:** 🟠 HIGH
- **Estimated Effort:** 2 hours
- **Category:** Feature Completion
- **Files to Modify:**
  - `lib/screens/songs/songs_list_screen.dart`
- **Implementation Steps:**
  1. Add `_searchQuery` state variable
  2. Implement `_filterSongs()` method
  3. Connect search field `onChanged` callback
  4. Update UI to show filtered results
  5. Add search to bands and setlists screens
- **Acceptance Criteria:**
  - [ ] Search filters songs by title
  - [ ] Search filters songs by artist
  - [ ] Search filters songs by tags
  - [ ] Search is case-insensitive
  - [ ] UI updates in real-time
- **Dependencies:** None
- **Risk:** Low

---

### Task 1.8: Complete Profile Settings
- **ID:** TODO-101-1.8
- **Status:** ⬜ Pending
- **Priority:** 🟠 HIGH
- **Estimated Effort:** 8 hours
- **Category:** Feature Completion
- **Files to Modify/Create:**
  - `lib/screens/profile_screen.dart`
  - `lib/screens/profile/edit_profile_screen.dart` (create)
  - `lib/screens/profile/change_password_screen.dart` (create)
  - `lib/screens/profile/theme_settings_screen.dart` (create)
- **Implementation Steps:**
  1. Implement display name editing
  2. Implement email change request
  3. Implement password reset
  4. Add theme preference (light/dark/system)
  5. Add notification settings
  6. Implement account deletion flow
- **Acceptance Criteria:**
  - [ ] Users can edit profile
  - [ ] Users can change password
  - [ ] Users can change theme
  - [ ] Users can delete account
- **Dependencies:** None
- **Risk:** Medium

---

## Phase 2: Architecture & Performance (Weeks 4-5)

**Goal:** Improve architecture, add validation, and optimize performance

### Task 2.1: Add Model Validation
- **ID:** TODO-101-2.1
- **Status:** ⬜ Pending
- **Priority:** 🟡 MEDIUM
- **Estimated Effort:** 6 hours
- **Category:** Architecture / Data Integrity
- **Files to Modify:**
  - `lib/models/song.dart`
  - `lib/models/band.dart`
  - `lib/models/setlist.dart`
  - `lib/models/user.dart`
- **Implementation Steps:**
  1. Add validation constructors to all models
  2. Validate required fields
  3. Validate field lengths
  4. Validate formats (email, URLs)
  5. Add custom exceptions
  6. Update forms to show validation errors
- **Acceptance Criteria:**
  - [ ] All models validate on creation
  - [ ] Validation errors are descriptive
  - [ ] Forms display validation errors
- **Dependencies:** Task 1.2
- **Risk:** Low

---

### Task 2.2: Add Caching for API Calls
- **ID:** TODO-101-2.2
- **Status:** ⬜ Pending
- **Priority:** 🟡 MEDIUM
- **Estimated Effort:** 4 hours
- **Category:** Performance
- **Files to Modify:**
  - `lib/services/spotify_service.dart`
  - `lib/services/musicbrainz_service.dart`
  - `lib/services/track_analysis_service.dart`
- **Implementation Steps:**
  1. Add cache maps to services
  2. Implement cache timestamp tracking
  3. Set cache duration (24 hours)
  4. Check cache before API calls
  5. Update cache after API calls
  6. Add cache clearing mechanism
- **Acceptance Criteria:**
  - [ ] Repeated requests use cache
  - [ ] Cache expires after 24 hours
  - [ ] Cache can be cleared manually
- **Dependencies:** None
- **Risk:** Low

---

### Task 2.3: Add Error Boundaries
- **ID:** TODO-101-2.3
- **Status:** ⬜ Pending
- **Priority:** 🟡 MEDIUM
- **Estimated Effort:** 6 hours
- **Category:** UX / Error Handling
- **Files to Create/Modify:**
  - `lib/widgets/error_boundary.dart` (create)
  - `lib/widgets/loading_state.dart` (create)
  - Update screens to use error boundaries
- **Implementation Steps:**
  1. Create `ErrorBoundary` widget
  2. Create `LoadingState` widget
  3. Wrap AsyncValue builders with error handling
  4. Add error logging
  5. Add retry mechanisms
- **Acceptance Criteria:**
  - [ ] Errors display user-friendly messages
  - [ ] Loading states consistent
  - [ ] Retry functionality works
- **Dependencies:** Task 1.6
- **Risk:** Low

---

### Task 2.4: Implement Offline Support
- **ID:** TODO-101-2.4
- **Status:** ⬜ Pending
- **Priority:** 🟡 MEDIUM
- **Estimated Effort:** 16 hours
- **Category:** Feature / Performance
- **Files to Modify:**
  - `lib/main.dart` (enable Firestore persistence)
  - `lib/widgets/offline_indicator.dart` (create)
  - `lib/services/offline_queue_service.dart` (create)
- **Implementation Steps:**
  1. Enable Firestore persistence
  2. Create offline indicator widget
  3. Implement connection status monitoring
  4. Create offline action queue
  5. Implement sync mechanism
  6. Add conflict resolution
  7. Test offline scenarios
- **Acceptance Criteria:**
  - [ ] App works offline
  - [ ] Changes sync when online
  - [ ] Offline indicator visible
  - [ ] Conflicts resolved gracefully
- **Dependencies:** None
- **Risk:** High

---

## Phase 3: Platform Expansion (Weeks 6-8)

**Goal:** Expand platform support and add new features

### Task 3.1: Test and Optimize for Mobile
- **ID:** TODO-101-3.1
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 20 hours
- **Category:** Platform / Mobile
- **Implementation Steps:**
  1. Set up Firebase for iOS and Android
  2. Test app on physical devices
  3. Fix platform-specific issues
  4. Optimize touch targets (min 48x48)
  5. Add platform-specific share functionality
  6. Test on multiple screen sizes
  7. Update app icons and splash screens
- **Acceptance Criteria:**
  - [ ] App runs on iOS
  - [ ] App runs on Android
  - [ ] No platform-specific bugs
  - [ ] Touch targets meet guidelines
- **Dependencies:** Task 0.2 (Firebase rules)
- **Risk:** Medium

---

### Task 3.2: Implement Tuner and Metronome
- **ID:** TODO-101-3.2
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 24 hours
- **Category:** Feature / Utility
- **Files to Create:**
  - `lib/screens/tuner_screen.dart`
  - `lib/screens/metronome_screen.dart`
  - `lib/services/audio_input_service.dart`
  - `lib/services/pitch_detection_service.dart`
- **Dependencies:**
  - `mic_manager` package
  - Audio processing libraries
- **Implementation Steps:**
  1. Add microphone permission handling
  2. Implement audio input capture
  3. Implement pitch detection algorithm
  4. Create tuner UI with note display
  5. Implement metronome with tempo control
  6. Add visual and audio feedback
  7. Add time signature support
- **Acceptance Criteria:**
  - [ ] Tuner detects pitch accurately
  - [ ] Metronome keeps accurate tempo
  - [ ] UI is responsive
  - [ ] Works on mobile platforms
- **Dependencies:** Task 3.1
- **Risk:** High

---

### Task 3.3: Add Real-time Collaboration Features
- **ID:** TODO-101-3.3
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 16 hours
- **Category:** Feature / Collaboration
- **Files to Modify/Create:**
  - `lib/widgets/presence_indicator.dart` (create)
  - `lib/services/collaboration_service.dart` (create)
  - Update existing screens for collaboration
- **Implementation Steps:**
  1. Implement user presence tracking
  2. Add presence indicators to UI
  3. Implement optimistic UI updates
  4. Add conflict resolution for concurrent edits
  5. Create activity feed
  6. Add real-time notifications
- **Acceptance Criteria:**
  - [ ] Users see who's online
  - [ ] Concurrent edits handled gracefully
  - [ ] Activity feed shows changes
- **Dependencies:** None (Firestore real-time already implemented)
- **Risk:** Medium

---

### Task 3.4: Add Usage Analytics
- **ID:** TODO-101-3.4
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 8 hours
- **Category:** Analytics
- **Dependencies:**
  - `firebase_analytics` package
- **Implementation Steps:**
  1. Add Firebase Analytics to project
  2. Configure for web and mobile
  3. Track key events:
     - User registration
     - Song created/updated/deleted
     - Band created/joined
     - Setlist created/exported
     - Login/logout
  4. Set up Analytics dashboard
  5. Document events in README
- **Acceptance Criteria:**
  - [ ] Analytics configured
  - [ ] Key events tracked
  - [ ] Dashboard accessible
- **Dependencies:** None
- **Risk:** Low

---

## Phase 4: Polish & Optimization (Weeks 9-10)

**Goal:** Final polish, accessibility, and performance optimization

### Task 4.1: Improve Accessibility
- **ID:** TODO-101-4.1
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 8 hours
- **Category:** Accessibility / UX
- **Implementation Steps:**
  1. Add semantic labels to all widgets
  2. Ensure color contrast meets WCAG AA
  3. Test with screen readers (VoiceOver, TalkBack)
  4. Add keyboard navigation (web)
  5. Add focus management
  6. Test with accessibility tools
  7. Document accessibility features
- **Acceptance Criteria:**
  - [ ] All interactive elements labeled
  - [ ] Color contrast passes WCAG AA
  - [ ] Screen reader compatible
  - [ ] Keyboard navigable
- **Dependencies:** None
- **Risk:** Low

---

### Task 4.2: Optimize Build Performance
- **ID:** TODO-101-4.2
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 8 hours
- **Category:** Performance
- **Implementation Steps:**
  1. Add `const` constructors everywhere possible
  2. Use `RepaintBoundary` for expensive widgets
  3. Implement lazy loading for lists
  4. Add pagination for song/band lists
  5. Profile app with DevTools
  6. Fix performance bottlenecks
- **Acceptance Criteria:**
  - [ ] Build method optimized
  - [ ] Lists use lazy loading
  - [ ] No jank in DevTools
  - [ ] 60 FPS maintained
- **Dependencies:** Task 1.6 (reusable widgets)
- **Risk:** Low

---

### Task 4.3: Add API Documentation
- **ID:** TODO-101-4.3
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 12 hours
- **Category:** Documentation
- **Implementation Steps:**
  1. Add dartdoc comments to all public APIs
  2. Add examples to complex methods
  3. Generate documentation with `dart doc`
  4. Deploy to GitHub Pages
  5. Link from README
- **Acceptance Criteria:**
  - [ ] All public APIs documented
  - [ ] Documentation generated
  - [ ] Deployed to GitHub Pages
- **Dependencies:** None
- **Risk:** Low

---

### Task 4.4: Set Up CI/CD Pipeline
- **ID:** TODO-101-4.4
- **Status:** ⬜ Pending
- **Priority:** 🟢 LOW
- **Estimated Effort:** 4 hours
- **Category:** DevOps / CI/CD
- **Files to Create:**
  - `.github/workflows/test.yml`
  - `.github/workflows/deploy.yml`
- **Implementation Steps:**
  1. Create GitHub Actions workflow for tests
  2. Add linting check
  3. Add test execution
  4. Add automated deployment
  5. Add branch protection rules
- **Workflow Configuration:**
  ```yaml
  name: Tests
  on: [push, pull_request]
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v3
        - uses: subosito/flutter-action@v2
        - run: flutter pub get
        - run: flutter analyze
        - run: flutter test
  ```
- **Acceptance Criteria:**
  - [ ] Tests run on PR
  - [ ] Linting enforced
  - [ ] Deployment automated
- **Dependencies:** Task 1.2, 1.3, 1.4 (tests must exist)
- **Risk:** Low

---

## Task Summary by Priority

### 🔴 Critical (4 tasks, 18 hours)
- [ ] 0.1: Move API keys to environment variables (2h)
- [ ] 0.2: Firestore security rules (4h)
- [ ] 1.1: Refactor add_song_screen.dart (8h)
- [ ] 1.2: Model unit tests (4h)

### 🟠 High (6 tasks, 50 hours)
- [ ] 0.3: Stricter linting (4h)
- [ ] 1.3: Provider tests (8h)
- [ ] 1.4: Widget tests (16h)
- [ ] 1.5: Integration tests (12h)
- [ ] 1.6: Populate widgets/ (12h)
- [ ] 1.7: Search functionality (2h)
- [ ] 1.8: Profile settings (8h)

### 🟡 Medium (4 tasks, 32 hours)
- [ ] 2.1: Model validation (6h)
- [ ] 2.2: API caching (4h)
- [ ] 2.3: Error boundaries (6h)
- [ ] 2.4: Offline support (16h)

### 🟢 Low (8 tasks, 100 hours)
- [ ] 3.1: Mobile testing (20h)
- [ ] 3.2: Tuner/metronome (24h)
- [ ] 3.3: Collaboration (16h)
- [ ] 3.4: Analytics (8h)
- [ ] 4.1: Accessibility (8h)
- [ ] 4.2: Performance (8h)
- [ ] 4.3: API docs (12h)
- [ ] 4.4: CI/CD (4h)

---

## Task Dependencies Graph

```
Phase 0 (Critical)
├── 0.1 ────────────────────────────────┐
├── 0.2 ────────────────────────────────┤
└── 0.3 ────────────────────────────────┘
              ↓
Phase 1 (Quality & Testing)
├── 1.1 ────────────────────────────────┐
├── 1.2 ──→ 1.3 ──→ 1.4 ──→ 1.5        │
├── 1.6 ────────────────────────────────┤
├── 1.7 ────────────────────────────────┤
└── 1.8 ────────────────────────────────┘
              ↓
Phase 2 (Architecture)
├── 2.1 (depends on 1.2) ───────────────┐
├── 2.2 ────────────────────────────────┤
├── 2.3 (depends on 1.6) ───────────────┤
└── 2.4 ────────────────────────────────┘
              ↓
Phase 3 (Platform)
├── 3.1 (depends on 0.2) ───────────────┐
├── 3.2 (depends on 3.1) ───────────────┤
├── 3.3 ────────────────────────────────┤
└── 3.4 ────────────────────────────────┘
              ↓
Phase 4 (Polish)
├── 4.1 ────────────────────────────────┐
├── 4.2 (depends on 1.6) ───────────────┤
├── 4.3 ────────────────────────────────┤
└── 4.4 (depends on 1.2-1.4) ───────────┘
```

---

## Parallel Execution Groups

### Group A: Security & Quality (Can run in parallel)
- 0.1: Environment variables
- 0.2: Firestore rules
- 0.3: Linting

### Group B: Testing (Sequential within group, parallel with Group C)
- 1.2 → 1.3 → 1.4 → 1.5 (must be sequential)

### Group C: Refactoring & Features (Can run parallel with Group B)
- 1.1: Refactor add_song_screen
- 1.6: Create widgets
- 1.7: Search functionality
- 1.8: Profile settings

### Group D: Architecture (After Phase 1)
- 2.1: Validation
- 2.2: Caching
- 2.3: Error boundaries
- 2.4: Offline (independent)

### Group E: Platform & Features (After Phase 2)
- 3.1: Mobile testing
- 3.2: Tuner/metronome
- 3.3: Collaboration
- 3.4: Analytics

### Group F: Polish (Final phase)
- 4.1: Accessibility
- 4.2: Performance
- 4.3: Documentation
- 4.4: CI/CD

---

## Quick Start Commands

### Run All Tests
```bash
flutter test
```

### Run Linting
```bash
flutter analyze
```

### Check Test Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run Integration Tests
```bash
flutter test integration_test/
```

### Build for Web
```bash
flutter build web --release
```

### Deploy to Firebase
```bash
firebase deploy
```

---

## Progress Tracking

### Sprint 1 (Week 1-2): Critical Tasks
- [ ] 0.1: Environment variables
- [ ] 0.2: Firestore rules
- [ ] 0.3: Linting
- [ ] 1.1: Refactor add_song_screen
- [ ] 1.2: Model tests

### Sprint 2 (Week 3-4): Testing
- [ ] 1.3: Provider tests
- [ ] 1.4: Widget tests
- [ ] 1.5: Integration tests
- [ ] 1.6: Widgets directory
- [ ] 1.7: Search

### Sprint 3 (Week 5-6): Features
- [ ] 1.8: Profile settings
- [ ] 2.1: Validation
- [ ] 2.2: Caching
- [ ] 2.3: Error boundaries
- [ ] 2.4: Offline

### Sprint 4 (Week 7-8): Platform
- [ ] 3.1: Mobile testing
- [ ] 3.2: Tuner/metronome
- [ ] 3.3: Collaboration
- [ ] 3.4: Analytics

### Sprint 5 (Week 9-10): Polish
- [ ] 4.1: Accessibility
- [ ] 4.2: Performance
- [ ] 4.3: Documentation
- [ ] 4.4: CI/CD

---

**Last Updated:** February 19, 2026  
**Next Review:** After Sprint 1 completion
