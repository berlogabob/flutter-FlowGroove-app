# FlowGroove Deployment Guide

**Last Updated:** April 24, 2026  
**Version:** 0.13.4+183

## Deployment Modes

There are three distinct deployment paths in this repo.

### 1. GitHub Pages Preview: Hugo + Flutter

Safe preview path:

```bash
make -f Makefile.hugo deploy-all
```

Publishes:

- Hugo landing page to `docs/`
- Flutter web app to `docs/app/`

URLs:

- `https://berlogabob.github.io/flutter-FlowGroove-app/`
- `https://berlogabob.github.io/flutter-FlowGroove-app/app/`

### 2. GitHub Pages Flutter-Only Publish

```bash
make deploy-test
```

This publishes only the Flutter web app and overwrites `docs/` root output. Use it only when that destructive behavior is intentional.

### 3. Production FTP Deploy

```bash
make deploy-stable
```

Publishes:

- Hugo landing page to `https://flowgroove.app/`
- Flutter web app to `https://flowgroove.app/app/`

## Configuration Sources

### Demo Config

Used by default for preview-oriented builds:

- `web/config.demo.js`
- `assets/env.demo.json`

### Generated Runtime Config

Production config is generated from local non-tracked env sources and exported shell variables.

Relevant files:

- `web/config.template.js`
- `scripts/generate-web-config.sh`
- `scripts/inject-web-config.sh`
- `scripts/build-mobile-with-env.sh`
- `scripts/load-deploy-env.sh`
- `scripts/preflight-ftp-deploy.sh`

The generated web config is now public-only. For production web it should emit:

- `FIREBASE_API_KEY`
- `SPOTIFY_PROXY_URL` (optional)

## Recommended Workflows

### Local Hugo Development

```bash
make -f Makefile.hugo serve
```

### Safe GitHub Pages Preview

```bash
make -f Makefile.hugo deploy-all
```

### Production FTP Publish

Recommended local setup:

```bash
cp .env.example .env
cp .ftp-env.example .ftp-env  # optional FTP-only override
```

Required values include:

- `FTP_HOST`
- `FTP_USER`
- `FTP_PASS`
- `FTP_DIR` (optional; defaults in Makefile)
- `FIREBASE_API_KEY`

Then run:

```bash
make deploy-stable
```

This target now performs a preflight check before any backup or upload:

- loads `.env` and optional `.ftp-env`
- blocks deploy if tracked examples contain real FTP values
- blocks deploy if `web/config.js` is tracked
- blocks deploy if staged changes include backup/archive/secret-bearing paths

### Android Release

```bash
make release
```

This builds APK + AAB and attempts the tagged GitHub release flow.

Mobile builds now use compile-time dart-defines instead of bundled `assets/env.json`.
If local `.env` exists, the build script uses it. Otherwise it falls back to the tracked demo source `assets/env.demo.json`.
`TRACK_ANALYSIS_API_KEY` is intentionally excluded from client build inputs until that integration moves behind a backend proxy.

## What The Main Targets Do

### `make -f Makefile.hugo deploy-all`

1. Builds Hugo to `docs/`
2. Builds Flutter web with `/flutter-FlowGroove-app/app/` base href
3. Copies Flutter output into `docs/app/`
4. Commits and pushes `docs/`

### `make deploy-test`

1. Copies demo web config
2. Builds Flutter web for `/flutter-FlowGroove-app/`
3. Removes existing `docs/*`
4. Copies Flutter output into `docs/`
5. Commits and pushes the Flutter-only result

### `make deploy-stable`

1. Generates production web config
2. Builds Hugo with production base URL
3. Builds Flutter web with `/app/` base href
4. Backs up current FTP production state
5. Uploads Hugo to FTP root
6. Uploads Flutter to FTP `/app/`
7. Runs health checks and auto-rollback on failure

## Security Notes

Current production safeguards:

- `web/config.js` must stay generated and untracked
- generated web runtime config must stay public-only
- Spotify web traffic must go through `SPOTIFY_PROXY_URL`; do not emit direct Spotify/Twitter/Telegram/RapidAPI secrets into `window.env`
- client Telegram Bot API methods are not an approved production path
- non-web app builds must use compile-time dart-defines, not bundled secret-bearing asset files
- production deploys are blocked until local FTP/runtime env values are present
- preview/GitHub builds force demo config so a leftover production `web/config.js` cannot leak into preview output
- demo Firebase keys remain in tracked demo config files

Treat any direct third-party credential in client config as a bug, not a supported deploy mode.

## Validation Commands

### Analyzer

```bash
flutter analyze
flutter analyze lib test
```

### Tests

```bash
flutter test
flutter test test/config/
```

### Security Audit

```bash
bash test/security/git_audit_test.sh
```

## Known Deployment Risks

### Risk 1: Wrong GitHub Pages Command

- Safe dual deploy: `make -f Makefile.hugo deploy-all`
- Destructive Flutter-only deploy: `make deploy-test`

### Risk 2: Credential Hygiene Before FTP Deploy

If FTP credentials were previously exposed in tracked history or examples, rotate them before using `make deploy-stable`. The preflight gate protects the current tree, but it cannot rotate hosting credentials for you.

### Risk 3: Live Analyzer Backlog

Historical snapshots are archived under `oldarchive/` and excluded from analyzer scope, but the live repo still carries a large lint backlog in app and test code.

## Documentation

- [README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/README.md)
- [ARCHITECTURE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/ARCHITECTURE.md)
- [docs/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/README.md)
- [site/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/site/README.md)
- [docs/project-audit-2026-04-24.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/project-audit-2026-04-24.md)
