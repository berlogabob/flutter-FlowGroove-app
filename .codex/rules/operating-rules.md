# Operating Rules

This file is the normalized summary of the rule system discovered across the Qwen setup.

## Core Rules

1. User request required.
   No unsolicited work, no scope creep beyond the request.

2. Protected markdown stays read-only.
   Any markdown file marked with `tags: [user]` is treated as protected.
   Protected files may be read and referenced, but not modified, deleted, moved, or retagged.

3. Memory before change.
   Review `.codex/memory/CRITICAL_PROBLEMS.md` before making risky code or config changes.

4. Quality gates matter.
   Architecture review, testing, documentation, and code review were all enforced in the original workflow.

5. Session artifacts are historical.
   Files in `.codex/sessions/` are copied records of the Qwen workflow and may still mention original `.qwen/` paths.

6. Strict sequential mode is the default.
   One agent loop, one bounded milestone at a time, no central orchestrator.

7. No subagents by default.
   Delegation is off unless the user explicitly asks for it.

8. Control-plane files are mandatory for active work.
   Use `.codex/AGENTS.md`, `MEMORY.md`, `PLANS.md`, `STATUS.md`, `HANDOFF.md`, and `DECISIONS.md`.

9. Stop-and-fix before proceeding.
   If validation fails, resolve it before taking the next milestone.

## Workflow Notes

- The original system used a sequential multi-agent protocol and GOST-formatted outputs.
- That protocol is preserved in `sequential-workflow.md` for reference.
- For active use in this repo, prefer the normalized `.codex/` tree over the original path layout.

## Preferred Active Paths

- Control plane: `.codex/AGENTS.md`, `.codex/MEMORY.md`, `.codex/PLANS.md`, `.codex/STATUS.md`, `.codex/HANDOFF.md`, `.codex/DECISIONS.md`
- Agents: `.codex/agents/`
- Rules: `.codex/rules/`
- Memory: `.codex/memory/`
- Session state: `.codex/sessions/`
- Task briefs: `.codex/tasks/`
