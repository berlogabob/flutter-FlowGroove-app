# Agents

This folder contains the imported Qwen agent catalog in a flatter, Codex-friendly structure.

## What Was Moved

- 24 agent definition files were copied from the original `.qwen/agents/` source and are now maintained here.
- There was no separate `subagents/` directory in the source tree.
- In practice, the specialist agent prompt files are the subagent layer.

## Groups

- Master and gatekeeping:
  `mr-supervisor`, `mr-compliance`, `mr-quality-control`
- Planning and coordination:
  `mr-sync`, `mr-planner`, `mr-architect`, `mr-memory`
- Implementation and review:
  `mr-senior-developer`, `mr-cleaner`, `mr-widget-crafter`, `mr-theme-guardian`, `mr-optimization`, `mr-repetitive`, `ux-agent`, `creative-director`
- Testing and debugging:
  `mr-tester`, `mr-stupid-user`, `mr-android`, `mr-android-debug`, `mr-logger`
- Content and release:
  `mr-hugo`, `mr-seo`, `mr-content`, `mr-release`

## Normalization

- The prompt bodies were kept close to source.
- A small number of path references were updated to point at `.codex/` instead of `.qwen/`.
- Workflow rules and non-agent policy docs were moved into `../rules/`.
