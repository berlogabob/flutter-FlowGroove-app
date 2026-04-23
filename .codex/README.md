# Codex Workspace Mirror

This directory is a non-destructive mirror of the live Qwen project context that was found in:

- `.qwen/`
- `memory/`
- `QWEN.md`

The original source files remain untouched. `.codex/` is the normalized layout for working with the same material in a cleaner structure.

## Structure

- `agents/` — imported agent definitions. The specialist agent files are the effective subagents.
- `rules/` — protected-file policy, sequential workflow protocol, and a normalized operating-rules summary.
- `memory/` — memory bank plus migrated project learnings from `QWEN.md`.
- `sessions/` — copied session/runtime snapshots from the Qwen workflow.
- `tasks/` — copied task briefs and sprint assignments.
- `config/` — imported Qwen settings snapshots.
- `migration-map.md` — source-to-destination mapping and exclusions.

## Notes

- Use `.codex/` as the preferred reference tree.
- Historical files in `sessions/` and some copied learnings still contain original `.qwen/` references by design.
- Protected-source files were copied, not edited in place.
