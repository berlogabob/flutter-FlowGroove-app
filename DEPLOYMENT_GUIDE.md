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

Production config is generated from environment variables.

Relevant files:

- `web/config.template.js`
- `scripts/generate-web-config.sh`
- `scripts/inject-web-config.sh`

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

Required environment variables include:

- `FTP_HOST`
- `FTP_USER`
- `FTP_PASS`
- `FTP_DIR` (optional; defaults in Makefile)

Then run:

```bash
make deploy-stable
```

### Android Release

```bash
make release
```

This builds APK + AAB and attempts the tagged GitHub release flow.

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

Current repo caveats from the April 24, 2026 audit:

- `web/config.js` is currently tracked in git
- the security audit script fails because of that tracked file
- demo Firebase keys are present in tracked demo config files
- `test/security/git_audit_test.sh` expects `web/config.js.template`, while the repo currently uses `web/config.template.js`

Treat generated config files as sensitive regardless of whether the current values are demo or production.

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

### Risk 2: Tracked Config Artifact

The repo currently tracks `web/config.js`. That means generated config handling is not yet fully aligned with the intended security model.

### Risk 3: Live Analyzer Backlog

Historical snapshots are archived under `oldarchive/` and excluded from analyzer scope, but the live repo still carries a large lint backlog in app and test code.

## Documentation

- [README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/README.md)
- [ARCHITECTURE.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/ARCHITECTURE.md)
- [docs/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/README.md)
- [site/README.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/site/README.md)
- [docs/project-audit-2026-04-24.md](/Users/berloga/Documents/GitHub/flutter_repsync_app/docs/project-audit-2026-04-24.md)
