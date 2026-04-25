# PLANS

## Current Goal

Execute the remediation roadmap for the April 24 audit: security hardening first, then deploy reproducibility, test baseline recovery, architecture cleanup, and CI.

## Mode

- strict sequential
- no subagents by default
- file-based durable memory

## Validation

- web runtime config must stay public-only
- `make deploy-stable` must match the working Hugo `/` + Flutter `/app/` layout
- critical client privileged flows must move off the client path
- each milestone must include a concrete targeted validation command

## Milestones

| ID | Milestone | Status | Validation |
|---|---|---|---|
| M1 | Prepare the detailed remediation plan and align `.codex` state | complete | plan stored in docs and `.codex/` |
| M2 | Security stage 1: remove secret-bearing web config paths and disable client Telegram privileged API usage | complete | targeted tests and docs confirm public-only client config |
| M3 | Fix canonical FTP backup/upload/rollback paths in `Makefile` | complete | `make -n deploy-stable` shows correct lftp layout |
| M4 | Recover test baseline, provider testability, and CI after security/deploy stabilization | in progress | targeted regression path is green; quarantine inventory documents the remaining non-hermetic suites |

## Next Plan Template

For the next real task, replace the goal and use this shape:

| ID | Milestone | Status | Validation |
|---|---|---|---|
| M1 | Define bounded change | pending | command or review step |
| M2 | Implement | pending | tests/analyze/manual check |
| M3 | Update docs/memory/handoff | pending | files updated |
