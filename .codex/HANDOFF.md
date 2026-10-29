# HANDOFF

## Current handoff — 2026-10-24

Read `docs/plans/systemic-ux/PLAN.md`, `activity.json`, `HISTORY.md`, then BASELINE.md
and TARGET-UX.md. The task is whole-app systematic UX/UI remediation, documentation,
Graphify and verified history, not a new visual brand or immediate product rewrite.

No release while any open task/finding/check remains. GitHub issues (14 at snapshot)
were imported for re-verification, not auto-closed. First-release/Play-launch issues
can conflict with this literal hold; only the owner may resolve that policy conflict.

OPS-LAN is verified; see verification/OPS-LAN.json. Existing Pi studio / exact Ornith
35b completed read + correct final without global auth/provider reconfiguration.
Native delegate remains 401. Noninteractive subprocess must use stdin=DEVNULL;
keep no-context/no-skills/no-extensions/no-mcp and explicit tools for bounded work.
OPS-RUNNER verified in ../flutter_repsync_systemic_ux, fix/systemic-ux. No old
runner, global clean/checkout/add-A or cloud fallback. UX-007-R/I/S verified: two
bounded Ornith production edits plus parent regression test; 20 screen tests pass in isolation; cherry-pick efef7ca4 passed 47 related screen tests
on second01. UX-007-V stays pending for fresh device/TalkBack. NEW-002 tracks three adjacent FAB
callers. Preserve final merged-semantics regression and the original/tooltip/both
RED/RED/GREEN matrix; do not revert to raw SemanticsNode.label assertions.

Commands: `uv run --isolated --no-project python scripts/activity_plan.py check`,
`uv run --isolated --no-project python scripts/test_activity_plan.py`,
`make activity-status`. Publication gate must stay BLOCKED for the open registry.
Private device captures stay in ignored audit/; pre-existing untracked research in
docs/plans/unified-workspace/ is not part of the planning commit. No push/tag/deploy.

UX-006-I is verified on second01 e6d8f26b (64 primary related tests); UX-006-V is blocked
for fresh installed-device validation. Whole issue remains open. Use fix/ux006 worktree
for this slice; the older fix/systemic-ux worktree is divergent and was not reset.
Read-only brief d173a844e136 runs every 10 minutes; it never implements or closes tasks.

Earlier handoff retained below as history; do not treat its task queue as current.

**Last Updated:** 2026-08-22
**Branch:** `second01` (the working branch — releases only from here)

## Current Checkpoint

Event sharing — letting a non-member work one event — is **built, deployed and live**.
A 14-item security/robustness audit of it is **8 closed**, the rest tracked in
**[`EVENT_SHARING_BACKLOG.md`](../EVENT_SHARING_BACKLOG.md)** at the repo root, which is
written for a cold session: ten `E`-items with runnable metrics, the invariants that must
not regress, and the traps for running and deploying.

**Read that file first if you are continuing this work.** Start with **E1**.

Suites at close: **2237 Flutter · 57 rules · 98 callable**, all green.

## Must Read First

1. `EVENT_SHARING_BACKLOG.md` ← the live work queue
2. `.codex/AGENTS.md`
3. `.codex/MEMORY.md`
4. `.codex/STATUS.md`
5. `.codex/DECISIONS.md`

---

## What this session did

### Shipped: event sharing for non-members

A person can be attached to **one event** without joining the band — a guest musician, a
sound engineer, a videographer, a venue's art director, a wedding couple. Five areas
(`eventInfo`, `runningOrder`, `songDetail`, `stage`, `rider`) × hidden/view/edit, defaulted
by role preset. Anonymous capability link can *suggest*; anyone who *edits* signs in first
so every write carries an author.

Server: `functions/src/events.js` — 6 callables + 2 Firestore triggers, all deployed.
Client: `/event` route, share links with a "they will see…" preview, guest discovery,
per-area gating of the Event Kit editor.

### Fixed — security, all deployed and verified against production

| | What | How bad |
|---|---|---|
| **Band document was world-readable** | `allow read: if isAuthenticated()` — and `read` covers `list`, so **any signed-in account could list every band in the project** and read its member emails and its `inviteCode`, the join secret | Critical, pre-existing |
| **Guest could read the whole setlist doc** | Firestore reads whole documents; `getEventView`'s scoping was walked straight past | Critical |
| **Grants lived on a client-written doc** | An app build predating the fields wiped every grant on 2026-08-21, **six minutes before a gig**. Both builds were `0.23.0+361` | Critical |
| Band-delete and account-delete cascades | Firestore cascades nothing; orphaned grants and phantom invites | High |
| Demo account could claim a share | no demo guard in the callables | High |
| Suggestions rule open to any signed-in user | author check proves who you are, never that you were invited | Blocker |

### Fixed — reachability

The feature was correct on the server and unusable in the app: area editors had no door,
there was no link → sign in → edit path (`claimEventShare` wasn't even in the deployed
bundle — Dart tree-shook it because nothing called it), and a guest's view died on refresh.

### Also, unrelated to the feature

Tonight-of-the-gig data work on the **Flor+** band: 5 songs added, lyrics scraped for 9,
key/BPM derived where possible, artist unified to "Flor Damico", setlist built and
reordered for the Sputnik Bar gig.

---

## Needs checking / fixing

**Nothing here is a known-broken state — these are unverified claims and open risks.**

1. **The `/event` page has never rendered in a browser.** Widget tests cover it; nobody has
   loaded it. Needs a human or `claude-in-chrome`. → E10
2. **Installed native apps cannot join a band by invite code until they update.** Closing
   the band-document leak means the old build's preview query is now denied. Web is fine —
   the join screen was rewired to the `getBandInviteInfo` callable and deployed first.
3. **Guest event views are snapshots, not live.** Deliberate: reorder a set mid-gig and a
   guest must refresh. If live guest updates are ever wanted, that is when splitting
   `eventKit` into per-area documents earns its cost.
4. **`isDemoUserProvider` is permissive while loading** — gates 8 places including the join
   button. Server callables are the real boundary, so it produces wrong doors, not a leak.
   Decision not yet recorded. → E9
5. **`createShare` / `claimShare` / `revokeShare` have no tests.** → E6
6. **Suggestions currently land where nobody looks** — guests can submit, no band-side UI
   renders them. → E7
7. **Two `flutter analyze` errors are pre-existing** in `test/helpers/routed_test_harness.dart`
   and `test/screens/bands/band_songs_screen_test.dart`. Confirmed clean against HEAD;
   not from this session.

---

## Traps that cost time this session

- **Rules/callable tests need JDK 21+.** Default `java` is 17 and firebase-tools rejects it:
  `export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home; export PATH="$JAVA_HOME/bin:$PATH"`
- **`flutter test | tail` reports success on failure** — always `set -o pipefail`.
- **`firebase deploy` reports success while an index is still BUILDING.** Poll with a real
  query; the collection-group index took ~3 minutes after "Deploy complete".
- **Verify a rules deploy by fetching the live ruleset and diffing it** against the repo,
  not by trusting the deploy message.
- **Deploy the app before the rules** whenever a rules change removes a permission the live
  build still uses.
- **Setlists have TWO save paths** — `services/firestore_service.dart` and
  `repositories/firestore_setlist_repository.dart`. A guard added to one misses the other.
  That is exactly how the grant wipe shipped. → E1 consolidates them.

---

## Repo hygiene noted, not actioned

Several stray files predate this session and were **not** committed — they look like
accidental dumps rather than work:

- `functions/2026-06-24-*.txt`, `site/2026-06-29-*.txt`, `site/2026-06-30-*.txt`
  (local-command transcripts)
- `.opencode/`, `audit_reports/`

They are probably `.gitignore` candidates. Left untouched so the decision is the owner's.

UX-006-R completion: Ornith timed out (540 s, no final) and guessed 4 read attempts at 2 unallowlisted paths. Rejected; no retry. Hermes completed the three-file source review, recorded separate failed attempt and explicit actor change. UX-006-I still queued; authenticated active-MIDI regression first. Source review only, not a second UI fix.

UX-006-I integrated and accepted: e6d8f26b, 64 related primary tests, final analyze/format exit 0. UX-006-V remains blocked for fresh installed-device evidence. Periodic read-only brief d173a844e136 checks every 10 minutes; it does not drive implementation.

NEW-002-R accepted from three parent-checked source windows. Three one-production-file fix/test slices registered; NEW-002-I1 confirmed rendered RED, then Ornith added exactly one tooltip line in 28.47 s. Whole-file GREEN: 12 tests plus analyze/format/diff passed. Integrated as 5de705cb; 12 primary tests passed, I1 verified. NEW-002-I2 verified on fafd2624: 6 primary tests, analyze no issues. NEW-002-I3 now runs GREEN/readonly/band-scope/analyze (proc_dcdce8987aa4).

NEW-002-I1 verified on 5de705cb: 12 primary tests, accessible-name and no-edit guard checks; issue remains open. NEW-002-I2 confirmed RED, Ornith added one tooltip line, GREEN/roles/analyze pending as proc_8d7a1d8b3263. NEW-002-I3 has a reproduced empty-label RED and parent-reviewed one-line tooltip patch; independent GREEN pending.

NEW-002-I3 worktree checks passed: 2 tests, analyze no issues, format/diff 0. Integrated as 370b23f9; seven-file primary regression proc_e052664fe359 pending. No device acceptance. UX-009-R readonly triage launched as proc_bfff379b9a82: exactly two complete source files, no edits/import exploration.

I3 accepted on 370b23f9: 68 primary related tests passed; NEW-002-V blocked for fresh device/screen reader. UX-009-R source reviewed; launcher copied-allowlist error corrected without repeating model. Shared Home/Practice DashboardCard added as UX-009-I2; whole-screen test moved to new public PracticeScreen fixture; independent sections/Quick start must not be blocked globally. UX-009-I2 parent async-state RED running as proc_7b16a5452437. Registry: 33 issues /66 tasks.

UX-009-I2 model attempt timed out without edits/final; saved and rejected, no retry. Parent replaced empty fallback with AsyncValue.when for card content+semantics, retaining Card/InkWell/data chart/navigation/tokens. Whole card suite/analyze/format now runs as proc_acce872e0790 in worktree; not integrated or accepted. Registry 33/66, 12 verified tasks; two device verification blockers.

Card: 4-case interim GREEN, cached-refresh guard also passed in expansion; routed navigation fixture pending-timer cleanup fixed, final six-case replay proc_4d4c3eddc694 pending. No primary integration. UX-001-R readonly Home/Practice flow triage running proc_ef6ca6593645; preserve distinction source vs human-usability evidence, no nav redesign before DESIGN-01.

UX-009-I2 final six card cases passed (async text/semantics, data/empty, navigation true/false, cached refresh); analyze/format/diff exit 0, four infos from baseline expressions. Integrated 87bfe21f; eight-file primary regression proc_7c4f32232b38 pending. UX-001-R source accepted with corrected visual/semantics claims; UX-001-I blocked on DESIGN-01. NEW-003 readonly-card semantics registered (R verified, I after card-state acceptance, V/device blocked). Registry 34 issues/69 tasks, 14 verified tasks, not 14 fixed problems.

UX-009-I2 accepted on 87bfe21f: 74 primary related tests passed, hashes match six-case worktree suite. Full PracticeScreen independent async sections remain UX-009-I (queued). NEW-003-I rendered readonly semantics RED launched proc_d5b3ef9e53bc; only test fixture edited so far. No active Ornith generation. Registry 34 issues/69 tasks; verified task count includes research/infrastructure, not closed product issues.

NEW-003-I RED confirms readonly merged label incorrectly says Tap to start. One model attempt timed out after source read/no edit; attempt saved, no retry. Parent conditional label patch and both readonly/tappable rendered assertions prepared. Full seven-case suite/analyze/format proc_740851d3d2bd pending; not integrated.

NEW-003-I code integrated 6d26f9ef after seven-case worktree PASS and analyze/format/diff 0 (four baseline infos). Primary replay proc_cc582a08c4b7 pending. UX-009-I whole public PracticeScreen fixture starts with homework async lifecycle + independent Quick start, proc_dc3b5f9ed2dd RED pending. Only its test file created so far.

NEW-003-I accepted on 6d26f9ef: 75 primary related tests, seven-case worktree checks/analyze/format 0; device V remains blocked. UX-009-I actual PracticeScreen homework RED confirmed (missing Loading homework status, no fixture/backend failure). Ornith Homework-only tracer running proc_83a7b4a9f0b4 with 540 s model bound /600 s launcher, one source read +max2 edits; no repeated prior prompt. Recent-session and song-title state fixes still required before whole UX-009-I acceptance.

Luna lane authorized: Hermes CLI gpt-6-luna per-call, fix/luna-ux isolated worktree, project-only context/resumable session, no global model/memory changes. UX-002-R draft ready after 35.040 s; review pending. UX-008-R resume launched proc_baa2eec1e593 (first zero-token CLI-flag rejection preserved/corrected). Pi Luna OAuth 401; do not use that route without user login. Ornith Homework run timed out 540 s without tools, parent fallback required. PARALLEL-LANES.md defines reduced checkpoint overhead and unchanged release hold.

Luna pilot verified: UX-002-R draft 35.040 s, UX-008-R draft 75.644 s; exact same Hermes session resumed. Assigned file calls only; both reports pending parent review in fix/luna-ux, no production changes. Personal memory excluded, no global config changed. Parent now owns timed-out Homework slice. See PARALLEL-LANES.md; full checks/Graphify batched at integration points, targeted tests retained.

Queue owner: native supervisor 748ba92c74d8, every 3m, script-gated; instructions /Users/berloga/MyHermes/FlowGrooveStatus/QUEUE-SUPERVISOR.md. Foreground must not compete for leased files or start duplicate workers. UX-009-I Luna CLI disconnected: retain lease and inspect gateway session local-9e1843ff439773d2b421186920ec607d6c4e9732aec159ebf453a8a830d43e66 before redispatch, never resend work. Current reports/reviews/next ready steps must be advanced by controller, not wait for chat. Status job stays 10m. Release hold unchanged.
