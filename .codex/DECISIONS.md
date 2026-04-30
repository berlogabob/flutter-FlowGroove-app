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

## D-2026-04-24-08

**Decision:** Web runtime config is public-only. Privileged third-party secrets must not be emitted into `web/config.js` or `window.env`.

**Why:** The audit confirmed that secret-bearing client config remains the highest-risk surface. Web clients must use proxy/backend paths for privileged integrations.

## D-2026-04-24-09

**Decision:** Non-web builds use compile-time dart-defines instead of bundled `assets/env.json`, and client-side RapidAPI track analysis remains disabled until it has a backend path.

**Why:** Bundled env assets and direct client RapidAPI usage both keep privileged values in app-distributed artifacts. The safer default is generated public web config plus compile-time non-web inputs, with backend-only privileged integrations as the target state.

## D-2026-04-24-10

**Decision:** `functions/` may use narrowly scoped npm `overrides` for transitive security fixes when they stay within safe semver-compatible ranges.

**Why:** The direct dependency graph was already at current minor Firebase SDK versions, but critical/high audit findings remained in transitive packages. Safe overrides materially reduced risk without forcing unstable major dependency surgery.

## D-2026-04-24-11

**Decision:** Remaining skipped test suites stay quarantined until dedicated harnesses exist, and the quarantine inventory lives in `docs/test-quarantine-2026-04-24.md`.

**Why:** Attempting to unskip them immediately produced real failures tied to router/Firebase, connectivity method channels, and live audio/wakelock services. Keeping them documented and bounded is safer than pretending they are ready for CI.

## D-2026-04-29-12

**Decision:** Metronome runtime side effects must sit behind provider-backed boundaries, and the canonical metronome BPM contract is `10-260` across notifier logic and user-facing controls.

**Why:** The metronome fast path was not hermetic while `MetronomeNotifier` directly constructed platform services, and the old mixed BPM limits (`1-300`, `40-220`, `10-260`) created avoidable drift between provider logic, UI, and tests. One injectable runtime boundary plus one BPM contract makes the metronome stack testable and consistent.
