# Unified music workspace — discovery and proposal

Date: 2026-10-23. Owner: Hermes (orchestration and verification).
Scope: research only; no application changes, migration, commits, publication, or changes to saved musical material.

## Acceptance / progress
- [x] R01 Discover connected P30, current repository, existing Graphify graph and LAN Ornith model (65,536 context verified).
- [x] R02 Observe P30 navigation: song → map / Lab → practice → backing / pattern editor; document actual vs code-only evidence (EVIDENCE.md, 10 screenshots).
- [x] R03 Trace current domain/data/transport boundaries with Graphify and source locations (EVIDENCE.md).
- [x] R04 Delegate bounded tasks to LAN Ornith, inexpensive OpenAI and Claude; retain model, status, duration, artifacts and failures (tasks.json, ORCHESTRATION.md).
- [x] R05 Research primary-source workflows and select a lightweight design methodology (RESEARCH.md).
- [x] R06 Synthesize a single-workspace proposal: drums, keys, guitar, imported MIDI, song map, Lab, learn/practice/perform (PROPOSAL.md).
- [x] R07 Validate proposal against evidence and write staged delivery / tests / unresolved decisions (PROPOSAL.md, selected baseline: 56 tests passed).

## Agent tasks
Every task is read-only with respect to the app. Main agent owns final conclusions; model responses are untrusted drafts.

| ID | Agent/model requested | Small deliverable | Pass gate | Status |
|---|---|---|---|---|
| L01 | Ornith / LAN Studio, native delegate | Existing MIDI domain and reuse boundaries | source-backed findings; nonempty final content | FAILED 401; Hermes source-analysis fallback |
| L02 | Ornith / LAN Studio | Drums / keys / guitar view requirements | concise instrument matrix, no invented MIDI fingering | REVIEWED, corrections captured |
| L03 | Ornith / LAN Studio | Journey edge-case checklist | concrete scenarios, no new architecture framework | REVIEWED, corrections captured |
| L04 | Ornith / LAN Studio | Critique of written proposal | concrete contradictions; no new framework | REVIEWED, clarifications applied |
| O01 | OpenAI gpt-5.1-codex-mini | Inspect transport/section ownership | source paths and line numbers; read-only | FAILED unsupported account/model |
| O02 | OpenAI gpt-6-luna | Narrow shared-transport review | runtime model verified, source findings checked | REVIEWED |
| C01 | Claude Haiku → claude-haiku-5-5 | Independent critique of seamless workspace | bounded code-backed UX findings; read-only | REVIEWED, overstatements corrected |

Local requests run serially; cloud reviews may run in parallel. One bounded attempt per task; timeout/empty/reasoning-only output is a failure, not completion. Hermes takes over failed work; no silent model substitution. Evidence and agent outputs live alongside this plan.

## Safety
Use existing songs only for inspection. Do not save, delete, import, alter tracks or mix, or change sharing/permissions. Playback may be briefly started and stopped if needed. Device screenshots are evidence; observations are not user testing. Existing device-pass reports are historical, not a current execution result.

Result: research complete, implementation intentionally not started. One session-only MIDI visibility flag was temporarily shown for inspection and then restored/read back; Play was not pressed. Full behavior, audio/hardware validation and user testing remain implementation/validation work, not checked-off achievements here.

## Phase 2 — deeper research (2026-10-23)
- [x] R08 P30 flow beyond Lab/Backing: Home, Practice, Recorder, Rehearsals, Concert, Setlists, tasks, import (phase2/P30-FLOW.md, D11–D22)
- [x] R09 Competitor first-party sources: Moises, Melodics, Yousician, Drumeo (phase2/sources/, Zendesk API + curl)
- [x] R10 Ornith extraction L05–L08 with mechanical quote check (40/40 literal) + Luna semantic check O03 + Haiku sources C02 / code check C03
- [x] R11 Synthesis: phase2/COMPETITORS.md; PROPOSAL §9 amendments A1–A7; EVIDENCE midiEntryId correction
- [x] R12 Ornith critique: L09 failed (length), L09b passed and was merged

## Next phase (not authorized implementation)
- [ ] Confirm the intended meaning of existing phrase/bar durations.
- [ ] Validate D12 micro-run interpretation with the owner (is each 5–60 s run a loop attempt?)
- [ ] Compare two low-fidelity workspace layouts on J1/J2/J4 with actual musicians.
- [ ] Approve the first thin implementation slice and its acceptance tests.

## Scientific grounding — targeted review (2026-10-23)
- [x] Recover previous evidence and separate weekly aggregate telemetry from observed practice; Loop already exists (D09).
- [x] Review nine original music-learning/HCI papers; verify bibliographic metadata, label full-text versus abstract access (`SCIENCE-PRACTICE.md`).
- [x] Propose a minimal continuity repair and separate usability and delayed-learning evaluation protocols; no application implementation.
- [x] Complete bounded document audit via parent fallback; independent Ornith run failed with HTTP 401 before analysis (see SCIENCE-PRACTICE §6).
- [ ] Validate actual practice goals, session boundaries and interruption/resume needs with musicians before implementation.

## Practice UX/UI — clarified primary scope (2026-10-23)
- [x] Record owner scope: Practice mode; research methods are UX/UI frameworks and HEART, not musical pedagogy or a whole-app/Concert redesign.
- [x] Locate and read existing Claude `app-audit` skill; record its course-provenance gap and metric/checklist corrections without modifying the skill (`PRACTICE-UX-RESEARCH.md`).
- [x] Read original Google HEART paper; refresh first-party competitor sources and distinguish core practice comparators from adjacent UX references.
- [x] Verify bounded Haiku critique of metrics; keep automated regression separate from human task success and HEART product metrics.
- [ ] Run matched practice-task competitor walkthroughs and a scoped device audit with approved test data.
- [ ] Compare modest in-place controls against a focused Practice workspace; measure Task success and Happiness with musicians before broader analytics or implementation.
