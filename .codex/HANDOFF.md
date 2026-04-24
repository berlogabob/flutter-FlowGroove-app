# HANDOFF

**Last Updated:** 2026-04-24

## Current Checkpoint

The root cleanup and Qwen-to-Codex consolidation pass is complete.

## Must Read First

1. `.codex/AGENTS.md`
2. `.codex/MEMORY.md`
3. `.codex/PLANS.md`
4. `.codex/STATUS.md`
5. `.codex/DECISIONS.md`

## Current Situation

- `.codex/` is the active internal control plane
- `memory/` remains the protected root memory bank
- Legacy context now lives under `oldarchive/`
- Historical session context remains under `.codex/sessions/`

## Next Agent Instructions

- Pick one bounded milestone only
- Define validation before editing
- Update `MEMORY.md`, `STATUS.md`, and this file before stopping

## Suggested Next Tasks

- resolve security audit failure around `web/config.js`
- reduce live analyzer noise in `lib/` and `test/`
- keep new work out of `oldarchive/` and use `.codex/` as the only active workflow layer
