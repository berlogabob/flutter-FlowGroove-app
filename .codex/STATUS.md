# STATUS

**Last Updated:** 2026-04-30

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
- Metronome runtime now uses injectable audio/haptics/wakelock boundaries instead of constructing platform services inside `MetronomeNotifier`
- Canonical metronome BPM behavior is normalized to `10-260` across provider logic and user-facing metronome inputs
- `test/services/metronome_service_test.dart`, `test/providers/metronome_provider_test.dart`, `test/widgets/tap_bpm_widget_test.dart`, and `test/widgets/metronome/bpm_controls_widget_test.dart` are green in the active fast path
- Auth/list screen tests now use a routed widget harness instead of plain `MaterialApp`
- `test/screens/login_screen_test.dart`, `test/screens/register_screen_test.dart`, and `test/screens/bands/my_bands_screen_test.dart` are restored from quarantine
- `test/screens/songs/songs_list_screen_test.dart`, `test/screens/setlists/setlists_list_screen_test.dart`, and full `flutter test test/screens` are green against the current unified-list contract
- `.github/workflows/checks.yml` now covers Flutter checks, security audit, deploy dry-run, `functions/` install verification, and the track-analysis regression test
- `functions/` installs cleanly, uses current minor Firebase SDKs, and now has 0 high / 0 critical production audit findings

## In Progress

- Test quarantine cleanup:
  - remaining non-hermetic suites are inventoried in `docs/test-quarantine-2026-04-24.md`
  - fast auth/router/list screen quarantine is cleared
- Repo-wide lint backlog reduction:
  - critical edited paths are stable enough for regression gating
  - full `flutter analyze lib test` still reports broad legacy lint debt

## Known Open Risks

- Some non-web privileged flows still exist as migration debt through dart-defines; backend-only remains the target state
- Full repo test suite is still not green end-to-end outside the targeted regression slice
- `functions/` still carries 11 production vulnerabilities, but only low/moderate Firebase-tree debt remains
- Remaining skipped suites are Firebase-emulator integration flows plus the FirestoreService placeholder

## Recommended Next Actions

1. Decide the FirestoreService/repository testability slice: injectable Firebase clients vs emulator-backed integration harness.
2. Continue reducing repo-wide lint backlog in touched subsystems until targeted analyze output is mostly silent.
3. Keep Firebase-emulator integration suites explicitly separated from the fast regression path.
