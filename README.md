# FlowGroove

[![Flutter Version](https://img.shields.io/badge/Flutter-3.41+-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.11+-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

FlowGroove is a Flutter app for managing band repertoires, setlists, and shared song databases for cover bands. This repository also contains the Hugo marketing site, a Telegram support bot, Firebase functions, the active `.codex/` internal workspace, and an `oldarchive/` area for legacy materials.

## Quick Start

### GitHub Pages Preview: Safe Dual Deploy

This is the safe path for previewing the Hugo site and Flutter app together:

```bash
make -f Makefile.hugo deploy-all
```

URLs:

- Landing page: `https://berlogabob.github.io/flutter-FlowGroove-app/`
- Flutter app: `https://berlogabob.github.io/flutter-FlowGroove-app/app/`

### Flutter-Only GitHub Pages Publish

This path publishes only the Flutter app and overwrites `docs/` root output:

```bash
make deploy-test
```

Use it only when you intentionally want a Flutter-only publish.

### Android Release

```bash
make release
```

Builds APK + AAB, tags the current version, and attempts to create a GitHub Release.

### Production FTP Deploy

1. Prepare local non-tracked env sources:

```bash
cp .env.example .env
cp .ftp-env.example .ftp-env  # optional FTP-only override
```

2. Replace all `REPLACE_ME_*` placeholders with real local values.
3. Run the production deploy:

```bash
make deploy-stable
```

`make deploy-stable` now runs a preflight gate before any backup or upload. It validates local env files, blocks tracked `web/config.js`, and refuses deploys when secret-bearing archive/backup paths are staged.

Deploy target:

- Hugo to `https://flowgroove.app/`
- Flutter web to `https://flowgroove.app/app/`

## Features

### Core App

- Song management with metadata, links, and structure editor
- Band management with membership and invite/join flows
- Setlist creation and organization
- Offline-first data flow with Hive-backed local caching
- Firebase Auth, Firestore, and Storage integration
- CSV import/export and PDF export
- Responsive desktop/mobile layout

### Music Tools

- Metronome with custom time signatures, accent patterns, presets, and transport controls
- Tuner with generate/listen modes and YIN-based pitch detection
- Regional instruments and multiple tunings
- Custom in-session tuning editor
- Auto/manual note detection
- Stage mode overlay
- Haptic feedback and A4 calibration
- Wakelock during tool usage

### Access And Workflow

- Demo account quick login
- Demo mode banner and read-only behavior
- Role-aware permission helpers
- Song autocomplete and BPM lookup provider layer
- Telegram support bot codebase included in `telegram_bot/`

## Repository Layout

### Main Areas

- `lib/` - Flutter application code
- `test/` - Flutter test suite
- `site/` - Hugo landing page source
- `docs/` - generated GitHub Pages output plus project reports
- `telegram_bot/` - Telegram support bot
- `functions/` - Firebase Functions source
- `.codex/` - active internal workspace for agents, rules, memory, tasks, and session control
- `memory/` - protected project memory bank retained at the repo root
- `oldarchive/` - archived Qwen context, exports, reports, snapshots, and legacy support files

### Current File Counts

- `lib/`: 240 Dart files
- `test/`: 97 Dart test files
- `site/`: 247 files
- `docs/`: 127 files
- `telegram_bot/`: 14 files

## Common Commands

| Command | Purpose | Notes |
|---|---|---|
| `make -f Makefile.hugo serve` | Run Hugo locally | Local landing-page development |
| `make -f Makefile.hugo deploy-all` | GitHub Pages dual deploy | Safe preview path |
| `make deploy-test` | Flutter-only GitHub Pages publish | Overwrites `docs/` root |
| `make deploy-stable` | Production FTP deploy | Hugo root + Flutter `/app/` |
| `make build-android` | Build APK | Demo config by default |
| `make release` | Build APK + AAB + release flow | Uses current git branch/tag |
| `flutter test` | Run the full Flutter suite | Not run in full during this audit pass |
| `bash test/security/git_audit_test.sh` | Security audit | Passes with warnings; history still needs periodic review |

## Documentation

### Core Docs

- [README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/README.md)
- [ARCHITECTURE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/ARCHITECTURE.md)
- [DEPLOYMENT_GUIDE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/DEPLOYMENT_GUIDE.md)
- [docs/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/README.md)
- [docs/project-audit-2026-04-24.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/project-audit-2026-04-24.md)

### Supporting Docs

- [site/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/site/README.md)
- [telegram_bot/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/telegram_bot/README.md)
- [memory/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/memory/README.md)
- [memory/CRITICAL_PROBLEMS.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/memory/CRITICAL_PROBLEMS.md)
- [.codex/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/.codex/README.md)

### Existing Reports

- [docs/fix-verification-report.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/fix-verification-report.md)
- [docs/performance-fixes-summary.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/performance-fixes-summary.md)
- [docs/tuner-debug-report.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/tuner-debug-report.md)
- [docs/tuner-testing-summary.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/tuner-testing-summary.md)
- [docs/tuner-ux-enhancement-summary.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/tuner-ux-enhancement-summary.md)

## Validation Snapshot

Historical audit snapshot before the April 24, 2026 FTP hardening pass:

- `flutter test test/config/`: 62 passed
- `bash test/security/git_audit_test.sh`: failed at that time on tracked `web/config.js`
- `flutter analyze`: 4411 issues across the whole repo before archival cleanup
- `flutter analyze lib test`: 3996 issues across live app/test code, dominated by lint backlog

See the dated audit report for details and prioritized findings. Legacy archived material now lives under `oldarchive/` and is excluded from analyzer scope.

## Security Notes

- Firebase configuration is runtime-injected for web and passed via compile-time defines for non-web builds
- Web runtime config is public-only: generated `web/config.js` should contain only `FIREBASE_API_KEY` and optional proxy URLs
- Spotify web access must go through `SPOTIFY_PROXY_URL`; direct client-credential mode is intentionally disabled on web
- Client-side Telegram Bot API methods are disabled; privileged Telegram actions belong in `functions/` or other backend paths
- Non-web builds no longer read `assets/env.json`; use compile-time `--dart-define` inputs instead
- Client-side RapidAPI track analysis is disabled until it moves behind a backend proxy
- `web/config.js` is a generated artifact and should stay untracked
- Demo Firebase keys are present in tracked demo config files
- Android/AAB build targets source demo or local `.env` values through [scripts/build-mobile-with-env.sh](/Users/berloga/Documents/GitHub/flutter_repsync_app/scripts/build-mobile-with-env.sh)
- If FTP credentials were ever stored in tracked files, rotate them before the next real production deploy

## Status

- Version: `0.13.4+183`
- Last updated: April 24, 2026
- Current project state: active development with `.codex/` as the canonical internal layer and `oldarchive/` for legacy context
