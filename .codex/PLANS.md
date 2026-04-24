# PLANS

## Current Goal

Consolidate the imported Qwen workflow into `.codex/`, clean the root, and archive non-working-root materials under `oldarchive/`.

## Mode

- strict sequential
- no subagents by default
- file-based durable memory

## Validation

- verify `.codex/` still contains the full imported agent/rule/task/session/config set
- verify missing design artifacts are now preserved under `.codex/design/`
- verify active docs and session scripts reference `.codex/` and `oldarchive/`
- verify the repo root contains only active working areas plus `oldarchive/`

## Milestones

| ID | Milestone | Status | Validation |
|---|---|---|---|
| M1 | Verify `.qwen` to `.codex` migration completeness and import missing design material | complete | agent/task/session/config/design parity confirmed |
| M2 | Update active docs, rules, and session scripts to the `.codex/` + `oldarchive/` scheme | complete | stale live references removed from active docs/scripts |
| M3 | Move legacy root artifacts, exports, backups, and temp state into `oldarchive/` | complete | root cleaned and archive structure created |
| M4 | Update memory, status, handoff, and decisions after cleanup | complete | control-plane files reflect the new canonical layout |

## Next Plan Template

For the next real task, replace the goal and use this shape:

| ID | Milestone | Status | Validation |
|---|---|---|---|
| M1 | Define bounded change | pending | command or review step |
| M2 | Implement | pending | tests/analyze/manual check |
| M3 | Update docs/memory/handoff | pending | files updated |
