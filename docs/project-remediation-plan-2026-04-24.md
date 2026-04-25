# Project Remediation Plan

**Date:** April 24, 2026
**Scope:** Security, deploy reproducibility, test baseline, architecture hardening, CI
**Status:** In progress

## Goal

Move the repo from "operational but fragile" to a predictable state where:

- privileged secrets are not used from client-facing web paths
- production deploy is reproducible from one canonical command
- the test suite has a trusted green baseline for critical flows
- provider and integration layers are testable without live Firebase singletons
- CI enforces security, build, and deploy checks automatically

## Workstreams

### 1. Security Hardening

**Target**

- no privileged third-party secret in tracked web runtime config
- no direct privileged Telegram Bot API calls from the client
- Spotify web flow works only through a backend proxy
- client env handling clearly distinguishes public runtime config from server-only secrets

**Milestones**

| ID | Task | Status | Validation |
|---|---|---|---|
| S1 | Remove secret-bearing values from `web/config.template.js` and generated web config path | complete | generated `web/config.js` exposes only public values |
| S2 | Force Spotify web to use `SPOTIFY_PROXY_URL` and block direct credential mode on web | complete | web path throws clear error without proxy; non-web direct mode still works |
| S3 | Disable privileged Telegram Bot API calls in client code and route future work to backend/functions | complete | only `openBotChat()` remains client-active |
| S4 | Remove mobile bundled secret dependence on `assets/env.json` | complete | production mobile builds no longer package privileged secrets |
| S5 | Move Track Analysis privileged API flow behind backend proxy or remove from client | complete | no client-side RapidAPI key usage |

### 2. Deploy Reliability

**Target**

- `make deploy-stable` reproduces the working release without manual lftp intervention
- backup and rollback point to real, restorable paths
- FTP layout matches GitHub release layout: Hugo `/`, Flutter `/app/`

**Milestones**

| ID | Task | Status | Validation |
|---|---|---|---|
| D1 | Fix FTP backup/download path handling | complete | backup target mirrors remote root into local backup directory |
| D2 | Fix Flutter FTP upload target so `/app/` receives bundle contents, not `app/web/` | complete | `make -n deploy-stable` shows `cd app; mirror build/web/ .` pattern |
| D3 | Fix rollback to restore from the saved local backup directory | complete | rollback uses recorded backup path and local `lcd` |
| D4 | Re-run production deploy from canonical target only | complete | live checks return `200` for `/`, `/app/`, `/app/config.js` |

### 3. Test Baseline Recovery

**Target**

- eliminate compile-time test failures first
- restore a trusted green path for critical song/metronome flows

**Milestones**

| ID | Task | Status | Validation |
|---|---|---|---|
| T1 | Fix compile break in `test/login_flow_null_check_test.dart` | complete | file compiles under `flutter test` |
| T2 | Resolve `SongFormData` beat-grid contract drift | complete | `song_form_data_test.dart` passes |
| T3 | Align metronome editor widget expectations with intended UI contract | complete | affected metronome widget tests pass |
| T4 | Reduce runtime skips and isolate non-hermetic suites | in progress | quarantine inventory stored in `docs/test-quarantine-2026-04-24.md` |

### 4. Architecture Hardening

**Target**

- provider graph can run in tests without live Firebase app initialization
- integrations have explicit boundaries between UI, client, and backend

**Milestones**

| ID | Task | Status | Validation |
|---|---|---|---|
| A1 | Introduce overridable Firebase/Auth abstractions in providers | complete | widget tests can inject fake auth state |
| A2 | Separate privileged integrations from UI-facing client services | complete | Telegram/Spotify/TrackAnalysis boundaries are explicit |
| A3 | Reduce lint noise in edited subsystems to reveal real regressions | in progress | targeted analyze runs are green enough for regression gating; repo-wide lint backlog remains |

### 5. CI And Dependency Health

**Target**

- security and regression checks run automatically on every branch
- `functions/` dependency state is installable and auditable

**Milestones**

| ID | Task | Status | Validation |
|---|---|---|---|
| C1 | Repair `functions/` dependency installation baseline | complete | `npm ls --depth=0` succeeds in `functions/` after clean install |
| C2 | Update vulnerable Firebase/function dependencies | complete | `npm audit --omit=dev` reduced to 11 issues with 0 high / 0 critical |
| C3 | Add CI workflows for Flutter analyze/test and security audit | complete | workflow files exist and run on PRs |
| C4 | Add deploy dry-run or preflight job | complete | CI verifies `make -n deploy-stable` and script checks |

## Execution Order

1. Security stage 1
2. Deploy reproducibility fixes
3. Test compile and contract failures
4. Provider/integration refactors
5. CI and dependency hardening

## Current Execution Slice

Started in this pass:

- web runtime config reduced toward public-only values
- Spotify web path moved toward proxy-only operation
- client Telegram privileged methods disabled
- non-web config loading moved from bundled `assets/env.json` toward compile-time dart-defines
- client-side RapidAPI track analysis removed pending backend replacement
- FTP backup/upload/rollback paths corrected in `Makefile`
- first compile break in `test/login_flow_null_check_test.dart` fixed
- `SongFormData` sparse beat-grid contract restored
- `MetronomePatternEditor` tests stabilized with explicit UI keys
- baseline CI workflow added for Flutter, security, deploy dry-run, and `functions/`
- `functions/` clean install and `npm ls` confirmed with a clean npm cache
- `functions/` direct dependencies updated to current minor versions and safe transitive overrides removed all high/critical audit findings
- remaining skipped suites were inventoried in `docs/test-quarantine-2026-04-24.md`

## Acceptance Gates

The repo is considered stabilized only when all of the following are true:

- no privileged secret is required in tracked web config files
- `make deploy-stable` works without manual FTP shell intervention
- critical Flutter tests are green on the main path
- provider-driven widget tests do not require live Firebase bootstrapping
- CI blocks regressions in security, deploy, and tests
