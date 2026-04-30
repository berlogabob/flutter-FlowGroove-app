# Test Quarantine Report

**Date:** April 24, 2026  
**Status:** Active quarantine inventory after screen/router recovery pass

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

Individual skipped tests:

- `test/services/firestore_service_test.dart`
  Reason: selected cases still depend on Firebase/platform setup outside the fast unit path.

## What Was Tried In This Pass

- Refactored `ConnectivityService` behind an injectable client boundary.
- Refactored metronome runtime dependencies behind injectable audio/haptics/wakelock providers.
- Restored `test/services/connectivity_service_test.dart` into the active test path.
- Unskipped connectivity and metronome unit/provider suites.
- Added a routed widget-test harness for auth and list screens.
- Unskipped `test/screens/login_screen_test.dart`, `test/screens/register_screen_test.dart`, and `test/screens/bands/my_bands_screen_test.dart`.
- Updated active `songs_list` and `setlists_list` suites to use the current router and unified list contract.
- Retired the skip-only `test/services/audio_engine_test.dart` placeholder in favor of hermetic metronome boundary coverage.

## Result

- The main targeted regression path remains green.
- `ConnectivityService` is no longer quarantined.
- `MetronomeNotifier` no longer constructs platform services directly and its unit/provider/widget path is green.
- `test/services/metronome_service_test.dart` and `test/providers/metronome_provider_test.dart` are no longer quarantined.
- The old `audio_engine_test.dart` placeholder debt is removed from quarantine.
- Login/register/my-bands are no longer quarantined.
- `flutter test test/screens` is green.
- Remaining skips are now explicitly documented instead of being treated as invisible backlog.
- The next reduction step is architectural, not editorial:
  - move Firestore service/repository singleton paths behind injectable boundaries or a Firebase emulator harness
  - keep Firebase-emulator-backed integration suites isolated from the fast unit path
