# Parallel work lanes — FlowGroove

Owner authorization: 2026-10-24, add Luna to accelerate independent work. No release-policy relaxation.

## Execution
- Parent Hermes: only writer of activity.json/PLAN/integration history; owns test acceptance and commits.
- Luna: Hermes CLI, per-invocation `--provider openai-codex --model gpt-6-luna --reasoning low`, isolated `/Users/berloga/Documents/GitHub/flutter_repsync_luna`, branch `fix/luna-ux`.
- Project memory: resumable Hermes session plus private PROJECT-CONTEXT.md in the lane's run directory. `--ignore-rules` excludes personal memory/global rules; only task file tools are enabled for read-only triage. These allowlists are instructions, not an OS sandbox; parent verifies output/diff.
- Ornith: one Studio request at a time. Preserve failed code attempts and do not retry their prompts. After repeated code timeouts (including 540 s without tools), do not leave critical-path implementation waiting for another blind retry. Parent directly completes the failed slice. Healthy bounded source research may continue independently.
- No shared mutable checkout, registry edits by workers, personal-memory synchronization, global provider/delegation changes, credentials, release/push/tag/deploy.

## Evidence before scaling
Luna real Hermes probe returned LUNA_READY. Pi's openai-codex OAuth refresh failed 401; no credential repair or alternate-model substitution. First Luna task UX-002-R produced exactly its assigned review file in 35.040 s, five file calls, source allowlist respected. This is a successful worker draft, not accepted UX findings, production code, or a general speed benchmark. Existing native delegate routing is not repinned globally; this is a separately launched Hermes worker.

## Reduce overhead, retain checks
- Assign coherent behavioral slices with explicit file leases, not one task per literal/string. Keep current production/test bounds until explicitly registered otherwise.
- Every fix needs targeted RED/GREEN through the public seam; final changed-source analyze/format/diff before acceptance.
- Do not repeat source analysis for every test-only fixture cleanup when production is unchanged; rerun the targeted fixture, then analyze the final slice.
- Run the combined related suite at integration/batch boundaries or when a shared component/navigation/audio/permissions change warrants it; not mechanically for every documentation checkpoint.
- Update the live registry on each phase/acceptance. Commit history and refresh full code Graphify at coherent integration checkpoints; metadata-only updates do not require another full AST/recluster cycle.
- Judge speed by independently accepted behavioral fixes and remaining product blockers, not by started agents or infrastructure/research task counts.

## Current lanes
Luna produced UX-002-R (35.040 s) and UX-008-R (75.644 s) drafts in the same resumed session; both await parent review. Parent owns direct completion of the timed-out PracticeScreen Homework slice. Further independent assignments follow parent review, not uncontrolled autonomous backlog consumption. No worker self-verifies or closes an issue. Device/human checks remain separate blockers.
