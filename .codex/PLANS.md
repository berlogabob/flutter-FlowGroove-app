# PLANS

## Current Goal

Operationalize `.codex/` as a strict sequential self-guided control plane.

## Mode

- strict sequential
- no subagents by default
- file-based durable memory

## Validation

- verify control-plane files exist and are internally consistent
- verify `.codex/README.md` and `.codex/rules/operating-rules.md` reference the new control plane

## Milestones

| ID | Milestone | Status | Validation |
|---|---|---|---|
| M1 | Create root control-plane files in `.codex/` | complete | files present |
| M2 | Encode sequential protocol and memory rules | complete | AGENTS/MEMORY/STATUS/HANDOFF/DECISIONS coherent |
| M3 | Update `.codex` index and rules docs | complete | README and operating-rules updated |

## Next Plan Template

For the next real task, replace the goal and use this shape:

| ID | Milestone | Status | Validation |
|---|---|---|---|
| M1 | Define bounded change | pending | command or review step |
| M2 | Implement | pending | tests/analyze/manual check |
| M3 | Update docs/memory/handoff | pending | files updated |
