# Session Management Scripts

**Location:** `scripts/session-start.sh` and `scripts/session-end.sh`

These scripts work with the active `.codex/` control plane.

## Quick Start

### Start A Session

```bash
./scripts/session-start.sh "Your goal"
```

### End A Session

```bash
./scripts/session-end.sh "What you accomplished"
```

## What `session-start.sh` Does

1. Reads `.codex/HANDOFF.md` and `.codex/STATUS.md`
2. Shows a short preview from `.codex/MEMORY.md`
3. Checks the current git branch and uncommitted changes
4. Lists available agents from `.codex/agents/`
5. Creates `.codex/sessions/ACTIVE_SESSION.md`

## What `session-end.sh` Does

1. Saves a snapshot to `.codex/sessions/SESSION_STATE.md`
2. Creates `.codex/sessions/NEXT_SESSION.md`
3. Suggests a manual export path under `.codex/sessions/exports/`
4. Cleans temporary files (`*.bak`, `*.tmp`, `.DS_Store`)
5. Reminds you to update `.codex/STATUS.md`, `.codex/HANDOFF.md`, and `.codex/DECISIONS.md`

## Files Used

```text
.codex/
├── MEMORY.md
├── STATUS.md
├── HANDOFF.md
├── DECISIONS.md
└── sessions/
    ├── ACTIVE_SESSION.md
    ├── SESSION_STATE.md
    └── NEXT_SESSION.md
```

## Recommended Flow

1. Start with `./scripts/session-start.sh "Goal"`
2. Work against one bounded milestone
3. Update `.codex/MEMORY.md`, `.codex/STATUS.md`, and `.codex/HANDOFF.md`
4. Run `./scripts/session-end.sh "Summary"` at a clean stopping point

## Customization

- Agents live in `.codex/agents/`
- Rules live in `.codex/rules/`
- Durable memory lives in `.codex/MEMORY.md` and `.codex/memory/`
