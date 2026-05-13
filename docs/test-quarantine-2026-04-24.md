# Test Quarantine Report

**Date:** May 13, 2026
**Status:** Quarantine closed for Firebase auth/setlist/quick-action coverage

## Purpose

Document intentionally skipped or isolated suites so test layering stays explicit and bounded.

## Current Quarantine

Group-level skips: none in the fast or emulator-backed acceptance path.

Individual skipped tests: none in the remediated auth/setlist/quick-action slice.

## What Was Tried In This Pass

- Refactored `ConnectivityService` behind an injectable client boundary.
- Refactored metronome runtime dependencies behind injectable audio/haptics/wakelock providers.
- Restored `test/services/connectivity_service_test.dart` into the active test path.
- Unskipped connectivity and metronome unit/provider suites.
- Added a routed widget-test harness for auth and list screens.
- Unskipped `test/screens/login_screen_test.dart`, `test/screens/register_screen_test.dart`, and `test/screens/bands/my_bands_screen_test.dart`.
- Updated active `songs_list` and `setlists_list` suites to use the current router and unified list contract.
- Retired the skip-only `test/services/audio_engine_test.dart` placeholder in favor of hermetic metronome boundary coverage.
- Retired the skip-only `test/services/firestore_service_test.dart` placeholder instead of keeping a non-test in the fast suite.
- Restored `test/build/android_config_isolation_test.dart` by updating it to the current config paths and turning placeholder assertions into static checks.
- Added the full `flutter test` suite to the GitHub Actions `Checks` workflow after the targeted regression step.
- Added a reusable Firebase emulator harness for Flutter acceptance tests.
- Reclassified `song_quick_action` from legacy integration placement into routed screen coverage.
- Reduced `auth_flow` and `setlist_management` to true emulator-backed acceptance flows.
- Added a dedicated GitHub Actions emulator gate instead of keeping Firebase acceptance work behind skips.

## Result

- The main targeted regression path remains green.
- Full `flutter test` remains green.
- `ConnectivityService` is no longer quarantined.
- `MetronomeNotifier` no longer constructs platform services directly and its unit/provider/widget path is green.
- `test/services/metronome_service_test.dart` and `test/providers/metronome_provider_test.dart` are no longer quarantined.
- The old `audio_engine_test.dart` placeholder debt is removed from quarantine.
- The old `firestore_service_test.dart` placeholder debt is removed from quarantine.
- Login/register/my-bands are no longer quarantined.
- `flutter test test/screens` is green.
- `test/build/android_config_isolation_test.dart` is no longer quarantined.
- `test/integration/auth_flow_test.dart` and `test/integration/setlist_management_test.dart` are active emulator-backed suites.
- `test/screens/home_quick_actions_test.dart` now covers the former quick-action navigation case in the correct layer.
- `test/integration` is now reserved for emulator-backed acceptance coverage, not general widget or model tests.
- Firebase acceptance runs in a separate CI gate from the fast suite.
- The canonical fast local command is `make test-fast`, which excludes `firebase-emulator` tagged suites by design.
