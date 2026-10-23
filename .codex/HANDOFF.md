# HANDOFF

## Current handoff — 2026-10-23

Read `docs/plans/systemic-ux/PLAN.md`, `activity.json`, `HISTORY.md`, then BASELINE.md
and TARGET-UX.md. The task is whole-app systematic UX/UI remediation, documentation,
Graphify and verified history, not a new visual brand or immediate product rewrite.

No release while any open task/finding/check remains. GitHub issues (14 at snapshot)
were imported for re-verification, not auto-closed. First-release/Play-launch issues
can conflict with this literal hold; only the owner may resolve that policy conflict.

Next bounded milestone: OPS-LAN. Existing Pi provider studio points at the Studio
LAN, model `ollama/ornith-1.5:35b`; model listing works, chat probe produced no final.
Do not claim a working agent from that. No global auth/provider reconfiguration.
Then OPS-RUNNER: do not run old plan_run.py's global clean/checkout/add-A/fallback.
One isolated worker/allowlist/deadline, Hermes tests and accepts each change.

Commands: `uv run --isolated --no-project python scripts/activity_plan.py check`,
`uv run --isolated --no-project python scripts/test_activity_plan.py`,
`make activity-status`. Publication gate must stay BLOCKED for the open registry.
Private device captures stay in ignored audit/; pre-existing untracked research in
docs/plans/unified-workspace/ is not part of the planning commit. No push/tag/deploy.

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
