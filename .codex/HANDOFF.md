# HANDOFF

**Last Updated:** 2026-04-30

## Current Checkpoint

The main audit remediation slice is implemented. Connectivity, metronome, and auth/router screen testability are now recovered; the active follow-up is Firestore/emulator quarantine cleanup and broader lint debt reduction.

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

## Next Agent Instructions

- Pick one bounded milestone only
- Define validation before editing
- Update `MEMORY.md`, `STATUS.md`, and this file before stopping

## Suggested Next Tasks

- reduce the remaining Firestore/emulator quarantine surface documented in `docs/test-quarantine-2026-04-24.md`
- continue lint-noise reduction in edited subsystems
- keep `functions/` vulnerability debt under watch for future upstream improvements
