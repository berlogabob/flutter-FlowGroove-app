# Codex Workspace Mirror

This directory is the active Codex workspace for the imported project context.

Its source material came from the legacy Qwen layout and the protected root memory bank:

- `oldarchive/qwen/`
- `memory/`

`.codex/` is now the canonical working layout for the imported agent, rule, memory, and session material.

It now also contains an active sequential self-guided control plane for ongoing work.

## Structure

- `AGENTS.md` — active sequential protocol and operating behavior
- `MEMORY.md` — distilled durable memory for active work
- `PLANS.md` — milestone plan and validation surface
- `STATUS.md` — current state snapshot
- `HANDOFF.md` — baton-passing file for the next session/agent
- `DECISIONS.md` — durable architectural and workflow decisions
- `agents/` — imported agent definitions. The specialist agent files are the effective subagents.
- `rules/` — protected-file policy, sequential workflow protocol, and a normalized operating-rules summary.
- `memory/` — memory bank plus migrated project learnings from the archived `QWEN.md`.
- `design/` — imported design notes and implementation proposals that did not fit the agent/rule/memory split.
- `sessions/` — copied session/runtime snapshots from the Qwen workflow.
- `tasks/` — copied task briefs and sprint assignments.
- `config/` — imported Qwen settings snapshots.
- `migration-map.md` — source-to-destination mapping and exclusions.

## Notes

- Use `.codex/` as the preferred reference tree.
- Use the root control-plane files for active sequential work.
- Historical files in `sessions/` and some copied learnings still contain original `.qwen/` references by design.
- Protected-source files were copied, not edited in place.
