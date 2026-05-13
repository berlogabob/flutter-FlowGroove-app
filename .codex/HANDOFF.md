# HANDOFF

**Last Updated:** 2026-05-13

## Current Checkpoint

The main audit remediation slice is implemented. Connectivity, metronome, auth/router screen testability, full Flutter test gating, static build-config test recovery, and Firebase emulator acceptance recovery are complete. The active follow-up is broader lint debt reduction and remaining singleton cleanup outside the remediated test paths.

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
  - dedicated `firebase-emulator-checks` CI job
  - `song_quick_action` reclassified into screen-layer coverage

## Next Agent Instructions

- Pick one bounded milestone only
- Define validation before editing
- Update `MEMORY.md`, `STATUS.md`, and this file before stopping

## Suggested Next Tasks

- continue lint-noise reduction in edited subsystems
- audit remaining direct Firebase singleton usage in non-remediated UI/services
- keep `functions/` vulnerability debt under watch for future upstream improvements
