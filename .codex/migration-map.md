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
| `.qwen/tuner_improvements_design.md` | `.codex/design/tuner-improvements-design.md` | Imported design note preserved as reference. |

## Archived Legacy Paths

The original source material and related historical outputs are preserved under `oldarchive/`:

- `.qwen/` → `oldarchive/qwen/.qwen/`
- `QWEN.md` → `oldarchive/qwen/QWEN.md`
- `backup/` → `oldarchive/backup/backup/`
- `chat-exports-collection/` → `oldarchive/exports/chat-exports-collection/`
- `git-history-analysis/` → `oldarchive/analysis/git-history-analysis/`
- `qwen-code-export-*.md` → `oldarchive/exports/`
- legacy export-analysis scripts → `oldarchive/legacy-scripts/`

## Migration Style

- Copy-first migration established `.codex/` from the imported Qwen source.
- Cleanup then archived the original Qwen root artifacts under `oldarchive/`.
- `.codex/` is now the active canonical tree for the imported workflow material.
- Normalization was applied where active docs and agent prompts needed current paths.

## Codex-Native Additions

After the initial mirror was created, `.codex/` was extended with a local control plane for strict sequential self-guided work:

- `.codex/AGENTS.md`
- `.codex/MEMORY.md`
- `.codex/PLANS.md`
- `.codex/STATUS.md`
- `.codex/HANDOFF.md`
- `.codex/DECISIONS.md`

These files are Codex-native additions rather than migrated Qwen source files.
