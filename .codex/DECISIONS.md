# DECISIONS

## D-2026-04-24-01

**Decision:** `.codex/` becomes the active control plane for imported project memory and sequential workflow.

**Why:** The imported Qwen material was useful but mostly archival. Active work needs a simpler, durable, Codex-friendly protocol.

## D-2026-04-24-02

**Decision:** Default execution mode is strict sequential self-guided work with no subagents.

**Why:** This matches the requested operating model: one agent loop, no orchestrator, explicit handoff through files, and bounded milestone progression.

## D-2026-04-24-03

**Decision:** Root control-plane files are `AGENTS.md`, `MEMORY.md`, `PLANS.md`, `STATUS.md`, `HANDOFF.md`, and `DECISIONS.md`.

**Why:** These files create a durable, low-dependency memory and planning system that survives sessions and supports handoff cleanly.

## D-2026-04-24-04

**Decision:** `.codex/memory/` remains the deep reference bank, while `.codex/MEMORY.md` is the distilled operational memory.

**Why:** Daily work needs a short memory surface; the full bank is still useful for deeper investigation.

## D-2026-04-24-05

**Decision:** `.codex/` is the canonical internal workspace, and the original Qwen root context is preserved under `oldarchive/qwen/`.

**Why:** Active work needs one authoritative workflow layer, but the imported source context still needs to remain available for audit and provenance.

## D-2026-04-24-06

**Decision:** Legacy exports, backups, historical analysis outputs, and local generated state live under `oldarchive/`, with `oldarchive/**` excluded from analyzer scope.

**Why:** The working root should stay focused on active code, docs, deployment, memory, and `.codex/`, while archived code should not pollute routine validation.

## D-2026-04-24-07

**Decision:** `scripts/session-start.sh` and `scripts/session-end.sh` now operate against `.codex/` rather than the legacy `.qwen/`/`QWEN.md` surface.

**Why:** Session tooling should match the current control plane so new work does not keep regenerating the retired layout.
