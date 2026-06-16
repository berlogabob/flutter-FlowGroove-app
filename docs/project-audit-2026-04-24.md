# FlowGroove Project Audit

**Date:** April 24, 2026  
**Scope:** whole-repo scan, doc review, targeted validation

## Executive Summary

The repository is active and substantial. The core product surfaces are present and coherent: Flutter app, Hugo site, Telegram bot, Firebase functions, and imported AI workspace context. The main immediate risks are documentation drift, a failing security audit because `web/config.js` is tracked, analyzer noise caused by historical backup code, and a very large lint backlog in live code.

This audit pass updated the main project docs to match the actual repo layout and deployment workflows.

## Repository Snapshot

### Inventory

- `lib/`: 240 Dart files
- `test/`: 97 Dart test files
- `site/`: 247 files
- `docs/`: 127 files
- `telegram_bot/`: 14 files

### Main Systems

1. Flutter application
2. Hugo landing page
3. Telegram support bot
4. Firebase Functions
5. Qwen/Codex workspace context

## Validation Results

### 1. Scoped Config Tests

Command:

```bash
flutter test test/config/
```

Result:

- 62 passed

### 2. Security Audit

Command:

```bash
bash test/security/git_audit_test.sh
```

Result:

- 3 passed
- 1 failed
- 4 warnings

Most important failure:

- `web/config.js` is tracked in git

Warnings included:

- `.env`-related files appear in git history
- `config.js` references appear in git history
- demo Firebase API key patterns appear in tracked demo config files
- the script expects `web/config.js.template`, but the repo currently has `web/config.template.js`

### 3. Analyzer

Commands:

```bash
flutter analyze
flutter analyze lib test
```

Results:

- whole repo: 4411 issues
- live app/test scope: 3996 issues

Observed hard errors in whole-repo analysis came from:

- `backup/config-modernization-2026-04-02/env_config.dart`
- `backup/config-modernization-2026-04-02/firebase_options.dart`

The narrowed `lib test` run was dominated by warnings and infos in the captured output rather than hard compile errors.

## Findings

### P1: Tracked Generated Config Artifact

`web/config.js` is tracked in git, and the security audit fails because of it.

Impact:

- breaks the intended generated-config security model
- keeps deployment hygiene in a permanently suspicious state

Recommended next step:

- decide whether `web/config.js` should be removed from version control
- align the deploy scripts and `.gitignore` with that decision

### P1: Conflicting Deployment Guidance

Before this audit pass, the repo documented `make deploy-test` as the normal test path while `docs/README.md` explicitly warned that it destroys Hugo output.

Impact:

- high operator error risk
- easy to publish the wrong artifact shape to GitHub Pages

Status:

- documentation updated in this pass

### P2: Historical Backup Code Pollutes Repo-Wide Analysis

The `backup/config-modernization-2026-04-02/` snapshot currently contributes explicit analyzer errors.

Impact:

- repo-wide `flutter analyze` looks materially worse than live app code alone
- noisy signals reduce trust in validation

Recommended next step:

- exclude backup code from analyzer scope or move it to a non-analyzed archive location

### P2: Large Lint Backlog In Live Code

The narrowed `flutter analyze lib test` pass still reported 3996 issues.

Common issue classes in the captured output:

- directive ordering
- constructor ordering
- redundant argument values
- unnecessary type annotations
- const opportunities

Impact:

- lowers signal-to-noise for real problems
- makes future regressions harder to spot

Recommended next step:

- define a lint debt reduction plan instead of trying to fix all of it in one pass

### P3: Help Text And Secondary Docs Were Stale

Stale references were found in:

- `README.md`
- `DEPLOYMENT_GUIDE.md`
- `site/README.md`
- `docs/README.md`
- `Makefile` help text

Status:

- updated in this pass

## Documentation Changes Made

Updated:

- `README.md`
- `ARCHITECTURE.md`
- `DEPLOYMENT_GUIDE.md`
- `docs/README.md`
- `site/README.md`
- `Makefile` help/documentation text

Added:

- `docs/project-audit-2026-04-24.md`

## Recommended Next Steps

1. Resolve the `web/config.js` tracking decision and make the security audit pass.
2. Move or exclude `backup/config-modernization-2026-04-02/` from repo-wide analyzer scope.
3. Triage the `flutter analyze lib test` backlog into batches.
4. Keep `make -f Makefile.hugo deploy-all` as the documented default GitHub Pages preview path.
5. If needed, follow this audit with a code cleanup pass rather than another documentation pass.
