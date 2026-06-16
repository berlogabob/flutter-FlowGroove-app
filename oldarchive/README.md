# Old Archive

This folder holds legacy and non-working-root material that was moved out of the active project surface.

## Purpose

- keep the repo root focused on working code, deployment files, docs, memory, and `.codex/`
- preserve imported Qwen context and historical artifacts without leaving them in the live root
- keep archived Dart and script code out of analyzer scope via `analysis_options.yaml`

## Layout

- `qwen/` — archived `.qwen/` source context and `QWEN.md`
- `backup/` — historical repo snapshots
- `exports/` — raw chat exports and export collections
- `analysis/` — git-history analysis outputs
- `legacy-scripts/` — scripts that only supported archived export/analysis flows
- `reports/` — root-level legacy reports that no longer belong in the active root
- `local-state/` — local generated state moved out of the root and ignored by git
