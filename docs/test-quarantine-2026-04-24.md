# Test Quarantine Report

**Date:** April 24, 2026  
**Status:** Active quarantine inventory after remediation pass

## Purpose

Document the remaining intentionally skipped test suites so they stay visible and bounded.

## Current Quarantine

Group-level skips:

- `test/services/metronome_service_test.dart`
  Reason: requires injectable audio/wakelock test doubles instead of live platform services.
- `test/providers/metronome_provider_test.dart`
  Reason: requires injectable audio/wakelock test doubles instead of live platform services.
- `test/screens/login_screen_test.dart`
  Reason: requires a refreshed router/Firebase widget harness after auth flow changes.
- `test/screens/register_screen_test.dart`
  Reason: requires a refreshed router/Firebase widget harness after auth flow changes.
- `test/screens/bands/my_bands_screen_test.dart`
  Reason: requires an updated Riverpod/Firebase widget harness for the current screen contract.
- `test/integration/auth_flow_test.dart`
  Reason: requires Firebase emulator or equivalent integration harness.
- `test/integration/setlist_management_test.dart`
  Reason: requires Firebase emulator or equivalent integration harness.
- `test/integration/song_quick_action_test.dart`
  Reason: requires Firebase emulator or equivalent integration harness.

Individual skipped tests:

- `test/services/audio_engine_test.dart`
  Reason: native platform audio behavior is not hermetic in the current Flutter test harness.
- `test/services/firestore_service_test.dart`
  Reason: selected cases still depend on Firebase/platform setup outside the fast unit path.

## What Was Tried In This Pass

- Refactored `ConnectivityService` behind an injectable client boundary.
- Restored `test/services/connectivity_service_test.dart` into the active test path.
- Unskipped the login/register/my-bands widget suites.
- Unskipped connectivity and metronome unit/provider suites.
- Verified they still fail for real harness reasons rather than stale skip flags.

## Result

- The main targeted regression path remains green.
- `ConnectivityService` is no longer quarantined.
- Remaining skips are now explicitly documented instead of being treated as invisible backlog.
- The next reduction step is architectural, not editorial:
  - inject audio and wakelock dependencies into `metronome_provider.dart`
  - refresh auth/router screen harnesses for login/register/my-bands
