# MEMORY

**Last Updated:** 2026-04-30

This is the distilled memory bank for active sequential work. Use it before `PLANS.md` execution and update it after durable discoveries.

## Stable Project Facts

- The repo contains a Flutter app, Hugo site, Telegram bot, Firebase Functions, and imported AI workspace context.
- `.codex/` is the normalized active reference tree.
- `memory/` remains the protected root memory bank.
- Archived Qwen source context lives under `oldarchive/qwen/`.
- `oldarchive/` is the single archive zone for legacy context, exports, backups, and local generated state.
- Safe GitHub Pages preview command is `make -f Makefile.hugo deploy-all`.
- `make deploy-test` is Flutter-only and overwrites `docs/` root output.
- Production deploy command is `make deploy-stable`.
- `docs/project-remediation-plan-2026-04-24.md` is the active roadmap for post-audit stabilization.

## Current Operational Risks

- Archived code is excluded under `oldarchive/**`, but the live repo still has a large lint backlog.
- Live app and test code still carry a large lint backlog.
- Archived exports, backup snapshots, and legacy session files must stay out of commits because even deletion diffs can surface old credential material.
- Production FTP deploys are intentionally blocked until local `.env` / `.ftp-env` values are present and placeholder-only tracked examples stay clean.
- Web runtime config must stay public-only. Privileged Spotify, Telegram, Twitter, and RapidAPI secrets do not belong in `window.env`.
- Spotify web access must go through `SPOTIFY_PROXY_URL`; direct client-credential mode is non-web only during migration.
- Client-side RapidAPI track analysis is retired until a backend replacement exists.
- Remaining skipped suites are tracked in `docs/test-quarantine-2026-04-24.md`; do not silently unskip them without adding the missing harnesses.
- Fast auth/list screen tests use `test/helpers/routed_test_harness.dart`; do not test `context.goNamed` flows with plain `MaterialApp` or `NavigatorObserver`.
- Login side effects are provider-backed through `analyticsClientProvider` and `pendingJoinCodeStoreProvider`; do not reintroduce direct `FirebaseAnalytics.instance` or static secure-storage reads in `LoginScreen`.
- `ConnectivityService` no longer owns a hard dependency on `Connectivity()`. Use `connectivityClientProvider` overrides with a local fake client in tests.
- `OfflineIndicator` only renders when `offlineProvider == true`; widget tests must override provider state explicitly instead of assuming an offline default.
- `MetronomeNotifier` no longer constructs audio, haptics, or wakelock services directly. Use `metronomeAudioClientProvider`, `metronomeHapticsProvider`, and `wakelockProvider` overrides in fast tests.
- Canonical metronome BPM contract is `10-260` across notifier logic and user-facing metronome inputs.
- `MetronomeState.copyWith` now supports explicit `null` clearing for `loadedSong` and `loadedSetlist`; use that path instead of assuming nullable fields can be cleared with the old `??` semantics.

## Durable Working Rules

- Default execution mode is strict sequential self-guided work.
- No subagents unless the user explicitly requests delegation.
- One milestone at a time.
- Validation before advancement.
- Memory, status, and handoff must be updated before the next milestone.
- Before committing, scan staged diffs for credential-bearing paths like `backup/`, `chat-exports-collection/`, `.env*`, and legacy exports.
- Before any FTP deploy, run the canonical `make deploy-stable` path so preflight checks enforce env loading, placeholder-only examples, and untracked `web/config.js`.
- When touching integrations, prefer backend/functions for privileged API flows and treat any client-side fallback as migration debt, not a target state.

## Reference Bank

Use these deeper memory sources when needed:

- `.codex/memory/CRITICAL_PROBLEMS.md`
- `.codex/memory/SECURITY_ISSUES.md`
- `.codex/memory/BUILD_DEPLOYMENT_ISSUES.md`
- `.codex/memory/DEPENDENCY_ISSUES.md`
- `.codex/memory/project-learnings.md`

## Update Rule

Add only durable facts here:

- architecture truths
- deployment truths
- recurring failure patterns
- project-wide constraints
- decisions that should survive session changes
