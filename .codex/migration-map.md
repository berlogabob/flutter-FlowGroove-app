# Migration Map

This file records how the live Qwen structure was mirrored into `.codex/`.

## Source To Destination

| Source | Destination | Notes |
|---|---|---|
| `.qwen/agents/*.md` | `.codex/agents/*.md` | Agent definitions copied. Rule-only files split out separately. |
| `.qwen/agents/PROTECTED_FILES_RULE.md` | `.codex/rules/protected-files.md` | Copied and lightly path-normalized. |
| `.qwen/agents/sequential-workflow.md` | `.codex/rules/sequential-workflow.md` | Copied as historical workflow protocol. |
| `.qwen/agents/README.md` + rule-heavy `QWEN.md` sections | `.codex/rules/operating-rules.md` | Normalized summary. |
| `memory/*.md` | `.codex/memory/*.md` | Memory bank copied intact. |
| `QWEN.md` | `.codex/memory/project-learnings.md` | Migrated as project learnings. |
| `.qwen/ACTIVE_SESSION.md` | `.codex/sessions/ACTIVE_SESSION.md` | Historical copy. |
| `.qwen/NEXT_SESSION.md` | `.codex/sessions/NEXT_SESSION.md` | Historical copy. |
| `.qwen/SESSION_STATE.md` | `.codex/sessions/SESSION_STATE.md` | Historical copy. |
| `.qwen/PROJECT_SUMMARY.md` | `.codex/sessions/PROJECT_SUMMARY.md` | Historical copy. |
| `.qwen/CHAIN_LOG.md` | `.codex/sessions/CHAIN_LOG.md` | Historical copy. |
| `.qwen/tasks/*.md` | `.codex/tasks/*.md` | Historical task briefs. |
| `.qwen/settings.json*` | `.codex/config/imported-qwen-settings*.json` | Imported provenance snapshots. |

## Intentionally Excluded

- `docs/archive/` — historical reports, outside the live agent/rules/memory system
- `git-history-analysis/` — analysis output, not active runtime configuration
- `qwen-code-export-*.md` — raw exports, large archival artifacts
- `scripts/session-start.sh`, `scripts/session-end.sh`, `scripts/README.session-management.md` — workflow tooling was scanned for context but not migrated in this pass

## Migration Style

- Non-destructive: source files remain where they were.
- Copy-first: `.codex/` is a mirror, not a replacement.
- Normalized only where useful: top-level docs and a few active agent prompts were updated to reference `.codex/` paths.

## Codex-Native Additions

After the initial mirror was created, `.codex/` was extended with a local control plane for strict sequential self-guided work:

- `.codex/AGENTS.md`
- `.codex/MEMORY.md`
- `.codex/PLANS.md`
- `.codex/STATUS.md`
- `.codex/HANDOFF.md`
- `.codex/DECISIONS.md`

These files are Codex-native additions rather than migrated Qwen source files.
