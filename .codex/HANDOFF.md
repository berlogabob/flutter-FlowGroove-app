# HANDOFF

**Last Updated:** 2026-06-05

## Current Checkpoint

The canonical library migration write-run tooling is implemented for exact external-ID candidates only. Production writes remain deferred; validate with Java 21+, require a fresh untruncated exact-candidate dry-run report, and review a no-write preview before any small explicit-project `--execute` batch.

## Must Read First

1. `.codex/AGENTS.md`
2. `.codex/MEMORY.md`
3. `.codex/PLANS.md`
4. `.codex/STATUS.md`
5. `.codex/DECISIONS.md`

## Current Situation

- `.codex/` is the active internal control plane
- `memory/` remains the protected root memory bank
- Legacy context now lives under `oldarchive/`
- Historical session context remains under `.codex/sessions/`
- Detailed remediation roadmap: `docs/project-remediation-plan-2026-04-24.md`
- Implemented code changes:
  - public-only web runtime config
  - Spotify web proxy-only path
  - client Telegram Bot API disabled
  - client RapidAPI track analysis removed
  - non-web compile-time define path replaces bundled env assets
  - `Makefile` FTP path corrections
  - auth/provider testability improvements
  - metronome audio/haptics/wakelock provider boundaries
  - canonical metronome BPM normalization to `10-260`
  - routed widget-test harness for login/register/bands/songs/setlists screen tests
  - `functions/` dependency hardening with safe overrides
  - full `flutter test` GitHub Actions gate
  - active `test/build/android_config_isolation_test.dart` coverage
  - reusable Firebase emulator harness for Flutter auth/setlist acceptance
  - Firebase auth/setlist acceptance moved to `integration_test/**`
  - dedicated Android emulator-backed `firebase-emulator-checks` CI job
  - debug-only Android cleartext allowance for local Firebase emulator host mapping
  - owner-only initial Firestore profile creation and safer canonical-song rule detection
  - normalized Firebase Auth invalid-login messaging
  - `song_quick_action` reclassified into screen-layer coverage
  - canonical library migration write-run tooling with validation preview, untruncated exact-candidate report enforcement, explicit-project guarded `--execute`, deterministic initial commits, and `docs/canonical-library-migration-runbook.md`

## Next Agent Instructions

- Pick one bounded milestone only
- Define validation before editing
- Update `MEMORY.md`, `STATUS.md`, and this file before stopping
- Local Java is currently 17 in this workspace; Firebase emulator migration tests require Java 21+

## Suggested Next Tasks

- run `npm --prefix functions test` under Java 21+
- generate and review a fresh untruncated exact-candidate dry-run report before any production migration batch
- continue lint-noise reduction in edited subsystems
