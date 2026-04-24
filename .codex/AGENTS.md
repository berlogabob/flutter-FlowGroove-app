# AGENTS

This file is the active control plane for `.codex/`.

## Mode

Default mode is `strict sequential self-guided`.

- One agent loop at a time
- No central orchestrator
- No subagents by default
- One bounded milestone before moving on
- Stop and fix before continuing if validation fails

Subagents are off unless the user explicitly asks for delegation.

## Must-Read Order

Before starting or resuming work, read in this order:

1. `.codex/AGENTS.md`
2. `.codex/MEMORY.md`
3. `.codex/PLANS.md`
4. `.codex/STATUS.md`
5. `.codex/HANDOFF.md`
6. `.codex/DECISIONS.md`
7. `.codex/rules/operating-rules.md`
8. `.codex/memory/CRITICAL_PROBLEMS.md` for risky code, build, deploy, or config work

## Sequential Protocol

For every milestone:

1. Read the control-plane files above.
2. Pick exactly one bounded milestone from `PLANS.md`.
3. State the validation command before editing when possible.
4. Make the smallest coherent change that completes the milestone.
5. Run validation.
6. If validation fails, fix it before taking the next milestone.
7. Update:
   - `MEMORY.md` if new durable facts or lessons appeared
   - `STATUS.md` with current state
   - `HANDOFF.md` with next-step context
   - `DECISIONS.md` if a real decision was made
8. Only then continue or stop.

## Memory Protocol

- Treat `.codex/MEMORY.md` as the distilled operational memory.
- Treat `.codex/memory/` as the deeper reference bank.
- Do not start the next milestone until memory and status are updated.
- Prefer durable facts, constraints, architecture, and failure patterns over narrative logs.

## Handoff Protocol

When stopping at a natural checkpoint:

1. Update `STATUS.md` with what is done, in progress, blocked, and next.
2. Write a short next-agent brief in `HANDOFF.md`.
3. Record any durable decision in `DECISIONS.md`.
4. Leave validation commands and expected outcome in the handoff.

## Worktree Guidance

If the user wants true multi-session or isolated parallel work:

- Prefer `git worktree` isolation
- Keep the same control-plane file set in each worktree
- Use `HANDOFF.md` and commits as the baton-passing mechanism

Without explicit user request, stay in a single sequential session.

## Hard Constraints

- User request required
- Protected markdown with `tags: [user]` stays read-only
- Prefer `.codex/` as the active reference tree; archived Qwen source lives under `oldarchive/qwen/`
- Historical files under `.codex/sessions/` remain reference material, not the active control plane
