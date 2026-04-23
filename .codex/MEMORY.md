# MEMORY

**Last Updated:** 2026-04-24

This is the distilled memory bank for active sequential work. Use it before `PLANS.md` execution and update it after durable discoveries.

## Stable Project Facts

- The repo contains a Flutter app, Hugo site, Telegram bot, Firebase Functions, and imported AI workspace context.
- `.codex/` is the normalized active reference tree.
- `.qwen/` and `memory/` remain preserved source context.
- Safe GitHub Pages preview command is `make -f Makefile.hugo deploy-all`.
- `make deploy-test` is Flutter-only and overwrites `docs/` root output.
- Production deploy command is `make deploy-stable`.

## Current Operational Risks

- `web/config.js` is tracked in git and currently causes the security audit to fail.
- Repo-wide `flutter analyze` is polluted by hard errors in `backup/config-modernization-2026-04-02/`.
- Live app and test code still carry a large lint backlog.

## Durable Working Rules

- Default execution mode is strict sequential self-guided work.
- No subagents unless the user explicitly requests delegation.
- One milestone at a time.
- Validation before advancement.
- Memory, status, and handoff must be updated before the next milestone.

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
