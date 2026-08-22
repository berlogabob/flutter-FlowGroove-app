# Event sharing — remaining work (trackable, measurable)

**Epic:** #180 · **Board:** Project #8 · **Last verified:** 2026-08-22
**Baselines when written:** 2237 Flutter · 57 rules · 98 callable — all green.

Written so a session with **no prior context** can pick this up and act. Findings come
from a 14-item security/robustness audit of event sharing: 8 closed and deployed, the
rest below. Format follows #177 — `ID — what. Metric: objective check`.

> Per board rules, issues are moved to **Done by the owner**, never by Claude.

---

## 1. What this feature is

Attach a person to **one event** without putting them in the band — a guest musician, a
sound engineer, a videographer, a venue's art director, a wedding couple.

**Five areas × three levels.** `eventInfo` · `runningOrder` · `songDetail` · `stage` ·
`rider`, each *hidden* / *view* / *edit*. Absent means hidden. Role presets fill the row;
manual ticks layer on top. → `lib/models/event_access.dart`

**Where authority lives** — never on a document a client writes:

```
bands/{b}/setlists/{s}/grants/{uid}    the grant. allow write: if false. Callables only.
users/{uid}/eventInvites/{setlistId}   discovery: "events shared with me". Owner-scoped.
eventShares/{tokenId}                  capability link. Stores a HASH, never the secret.
```

**One read path for guests:** `getEventView` in `functions/src/events.js`. A guest cannot
read the setlist document at all — Firestore reads whole documents, so a raw read would
hand over the stage plot, the rider and every roster uid regardless of grant. Scoping
happens server-side; an ungranted area is **absent from the payload**, not hidden in the UI.

**Two ways in, deliberately different:** a capability link (`/#/event?t=<id>.<secret>`)
needs no account and can only *suggest*; anyone who *edits* signs in and claims, so every
write carries an author.

---

## 2. Invariants — do not regress

Each is a scar from a real incident and each has a test that fails loudly.

| Invariant | Why | Test |
|---|---|---|
| Nothing authorization-shaped on a client-written document | Firestore has **no partial writes**, so such a field is only as durable as the oldest installed build. A build predating the fields wiped every grant on 2026-08-21, six minutes before a gig — both builds were `0.23.0+361`, so the version gave no warning | *"survives a full replacing set() that knows nothing about grants"* |
| Setlists have **TWO** save paths — `services/firestore_service.dart` **and** `repositories/firestore_setlist_repository.dart` — and both need `toJsonForSave()` + `merge: true` | A guard added to one silently misses the other. This is E1 | full suite |
| `eventKit` is written **only** through dotted field paths | stage and rider have separate editors and separate permissions; a whole-document write reverts whoever saved first | *"refuses a member's whole-document save that carries a stale event kit"* |
| A Firestore **update needs no read permission** | This is what lets an area editor write while being denied the document. If it ever stops holding, the sound engineer silently loses the stage plot | *"an area editor can WRITE without being able to READ"* |
| Loading is a **third answer**, not a definite one — `isEventGuestOf` returns `bool?` | Collapsing unknown into "member" handed guests every area at `edit` for that window | `test/providers/event_permissions_test.dart` |
| Never reintroduce a collection-group rule over `setlists` | `match /{path=**}/setlists/{id}` also matches **every user's personal setlists** | *"no longer exposes personal setlists through a collection group"* |
| Scoping happens on the server, never in the widget | Filtering in the UI leaves the data on the wire | *"a venue sees titles and NO key or BPM anywhere on the page"* |

---

## 3. Open backlog

- [ ] **E1 — Duplicate write layer** *(structural; do first)*
  `FirestoreService` and the repositories implement ~14 of the same operations, split by
  *operation* rather than deprecated, so both are load-bearing: reads stream through the
  repositories, writes go through the service — **except** `song_library_merge_service.dart`,
  which writes via `setlistRepository.saveSetlist` and routes to `saveBandSetlist` when a
  bandId is present. That split is the root cause that let the grant wipe happen.
  Fix: repositories become the only Firestore touchers; `FirestoreService` methods reduce
  to delegations (it already fronts songs via `SongRepository` — copy that pattern).
  **Metric:** `grep -c "collection('setlists')\|collection('bands')" lib/services/firestore_service.dart` → **0** (baseline **20**); all suites unchanged.

- [ ] **E2 — Share tokens never expire**
  W3C capability-URL guidance says they should. Add `expiresAt`, honoured in
  `resolveToken` beside `revoked`.
  **Metric:** an expired token and a garbage token return **byte-identical** errors, so
  the endpoint stays a non-oracle.

- [ ] **E3 — Suggestion flooding**
  No per-token cap exists (`grep -c suggestionCount functions/src/events.js` → 0). An
  anonymous link holder can fill a band's subcollection. Counter on the share document.
  **Metric:** the N+1th suggestion from one token is rejected; the Nth still succeeds.

- [ ] **E4 — A guest cannot see their own suggestion's status**
  `suggestions` is readable only by band members, so "the band decides" is invisible to
  the person who asked. Return the caller's own suggestions from `getEventView` rather
  than opening the subcollection — that also works for anonymous holders, who have no uid
  for a rule to match.
  **Metric:** an anonymous token holder's `getEventView` contains their suggestion and its
  status; another token's suggestions are absent.

- [ ] **E5 — `getEventView` song fan-out is unbounded**
  *(Correcting an earlier note in the issue history: it is already `Promise.all`, i.e.
  parallel, not sequential. The defect is that it is uncapped.)* Use `db.getAll(...)`.
  **Metric:** a 10-song event resolves in **≤2** Firestore round trips; a setlist above the
  cap is truncated **and says so** in the payload.

- [ ] **E6 — Client write wrappers untested**
  `createShare`, `claimShare`, `revokeShare` have **0** test references — the only grep
  hit is a comment saying so. The read path is covered; the write wrappers are not.
  **Metric:** each has ≥1 test through `eventShareServiceProvider`.

- [ ] **E7 — Suggestions land where nobody looks** *(issue #187)*
  Guests can submit today — live, deployed and tested — and **no band-side UI renders
  them**. `resolveSuggestion` exists in `lib/services/event_share_service.dart` and no
  screen calls it. Arguably a bug rather than deferred work.
  *(Do not grep for `suggestions` — 35 unrelated hits from song autocomplete, tags and
  stage gear. Grep for `resolveSuggestion` instead.)*
  **Metric:** `grep -rn "resolveSuggestion" lib --include='*.dart' | grep -v event_share_service | wc -l`
  → **≥1** (baseline **0**); and a suggestion submitted from a share link appears in the
  band's setlist UI and can be accepted or declined.

- [ ] **E8 — Stale `guestUids` index still live**
  Superseded by the `eventInvites` design. Removal needs `firebase deploy --force`, which
  also deletes anything else absent from the file.
  **Metric:** `gcloud firestore indexes fields list` shows no `guestUids` override — and the
  force-delete set was diffed **before** running it.

- [ ] **E9 — `isDemoUserProvider` is permissive while loading**
  Same class as the tri-state bug, inverted: for a *capability* provider `false` on loading
  denies (safe); for this *restriction* provider `false` permits. Gates 8 places including
  the join button. Pre-existing; the server callables are the real boundary, so it produces
  wrong doors rather than a leak. Fixing it naively flashes the demo banner for every real
  user on every cold start.
  **Metric:** a recorded decision (fix or accept, with reasoning) — and if fixed, a test that
  loading does not read as "not demo".

- [ ] **E10 — The `/event` page has never rendered in a browser**
  Widget tests now cover it; nobody has loaded it. Needs a human or `claude-in-chrome`.
  **Metric:** a screenshot of the live page plus a clean console, for one venue-scoped link
  and one edit link.

**Separate backlog:** #179 — pre-existing UI-vs-rules parity gaps (Song Lab ungated, tuner
presets, `storage.rules` letting any authenticated user write band audio).

---

## 4. Order

**E1** first — until it is done, every change to setlists or bands must be made twice or it
is wrong. Then **E2–E5** as one small server pass. Then **E7**, because suggestions going
into a void is worse than not having the feature. **E6** alongside whichever item touches
the client. **E8 / E9 / E10** last.

---

## 5. Running things — the traps

```bash
# Rules + callable tests need JDK 21+. The default java is 17 and firebase-tools rejects it.
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
cd functions && npm run test:rules && npm run test:callables

set -o pipefail          # `flutter test | tail` reports 0 on failure without this
flutter test
```

- **Deploy order: app first, then rules**, whenever a rules change removes a permission the
  live build still relies on.
- **Index builds are slow and `firebase deploy` lies about them** — it reported success
  while the collection-group index was still BUILDING. Poll with a real query instead.
- **Verify a rules deploy by fetching the live ruleset and diffing it** against the repo
  rather than trusting the deploy message:
  `GET https://firebaserules.googleapis.com/v1/projects/repsync-app-8685c/releases`
  (needs `-H "X-Goog-User-Project: repsync-app-8685c"`).
- Deploying the app is separate from releasing: `make deploy-app-hosting`.

---

## 6. Closed, for reference

Band-document leak (any signed-in account could **list every band** with member emails and
invite codes) · guest reading the whole setlist document · grants on a client-writable doc ·
setlist-delete and band-delete cascades · `deleteAccount` leaving grants behind · demo
account able to claim a share · suggestions rule open to any signed-in user · area editors
having no UI door · no claim flow · guest view dying on refresh.
