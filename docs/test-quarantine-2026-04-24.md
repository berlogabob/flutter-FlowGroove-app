# Test Quarantine Report

**Date:** May 3, 2026
**Status:** Active quarantine inventory after full Flutter test recovery

## Purpose

Document the remaining intentionally skipped test suites so they stay visible and bounded.

## Current Quarantine

Group-level skips:

- `test/integration/auth_flow_test.dart`
  Reason: requires Firebase emulator or equivalent integration harness.
- `test/integration/setlist_management_test.dart`
  Reason: requires Firebase emulator or equivalent integration harness.
- `test/integration/song_quick_action_test.dart`
  Reason: requires Firebase emulator or equivalent integration harness.

Individual skipped tests: none.

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

## Result

- The main targeted regression path remains green.
- Full `flutter test` is green with only Firebase-emulator integration groups skipped.
- `ConnectivityService` is no longer quarantined.
- `MetronomeNotifier` no longer constructs platform services directly and its unit/provider/widget path is green.
- `test/services/metronome_service_test.dart` and `test/providers/metronome_provider_test.dart` are no longer quarantined.
- The old `audio_engine_test.dart` placeholder debt is removed from quarantine.
- The old `firestore_service_test.dart` placeholder debt is removed from quarantine.
- Login/register/my-bands are no longer quarantined.
- `flutter test test/screens` is green.
- `test/build/android_config_isolation_test.dart` is no longer quarantined.
- Remaining skips are now explicitly documented instead of being treated as invisible backlog.
- The next reduction step is architectural, not editorial:
  - build a Firebase emulator harness for the remaining integration flows
  - keep Firebase-emulator-backed integration suites isolated from the fast unit path until that harness is CI-ready
