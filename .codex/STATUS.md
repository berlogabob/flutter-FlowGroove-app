# STATUS

**Last Updated:** 2026-04-29

## Current State

- `.codex/` is the canonical internal workspace for the imported agent and memory system.
- `oldarchive/` contains archived Qwen source context, exports, backups, legacy scripts, reports, and local generated state.
- Root operational files are active:
  `AGENTS.md`, `MEMORY.md`, `PLANS.md`, `STATUS.md`, `HANDOFF.md`, `DECISIONS.md`
- `docs/project-remediation-plan-2026-04-24.md` is the active stabilization roadmap.

## Completed

- Imported Qwen context was normalized into `.codex/`
- Legacy root artifacts were moved into `oldarchive/`
- `analysis_options.yaml` excludes `oldarchive/**`
- Web runtime config is public-only and `web/config.js` is generated/untracked
- Spotify web is proxy-first; client Telegram privileged calls are disabled
- Client-side RapidAPI track analysis was removed pending a backend replacement
- Non-web builds moved from bundled `assets/env.json` to compile-time dart-defines
- `Makefile` FTP backup/upload/rollback paths match the working `/` + `/app/` layout
- Targeted regression path is green, including config, Spotify, auth-provider, song-form, and metronome editor suites
- `ConnectivityService` now uses an injectable `ConnectivityClient` boundary instead of a direct method-channel dependency
- `test/services/connectivity_service_test.dart` is restored from quarantine and green
- `test/widgets/offline_indicator_test.dart` now explicitly overrides `offlineProvider` and is green against the current widget contract
- `.github/workflows/checks.yml` now covers Flutter checks, security audit, deploy dry-run, `functions/` install verification, and the track-analysis regression test
- `functions/` installs cleanly, uses current minor Firebase SDKs, and now has 0 high / 0 critical production audit findings

## In Progress

- Test quarantine cleanup:
  - remaining non-hermetic suites are inventoried in `docs/test-quarantine-2026-04-24.md`
  - next reduction step requires injectable audio/wakelock/router harnesses
- Repo-wide lint backlog reduction:
  - critical edited paths are stable enough for regression gating
  - full `flutter analyze lib test` still reports broad legacy lint debt

## Known Open Risks

- Some non-web privileged flows still exist as migration debt through dart-defines; backend-only remains the target state
- Full repo test suite is still not green end-to-end outside the targeted regression slice
- `functions/` still carries 11 production vulnerabilities, but only low/moderate Firebase-tree debt remains
- Login/register/my-bands and metronome service/provider tests still need dedicated harness refactors before they can be unskipped

## Recommended Next Actions

1. Refactor metronome layers to use injectable audio/wakelock adapters so their quarantined tests can rejoin CI.
2. Refresh login/register/my-bands widget harnesses for the current router and Firebase state model.
3. Continue reducing repo-wide lint backlog in touched subsystems until targeted analyze output is mostly silent.
