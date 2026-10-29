# Event sharing — remaining work (trackable, measurable)

**Epic:** #180 · **Board:** Project #8 · **Last verified:** 2026-08-22
**Baselines when written:** 2237 Flutter · 57 rules · 98 callable — all green.
**After the 2026-08-22 pass:** 2257 Flutter · 57 rules · 115 callable — all green.
**Status: 10 of 10 closed** (E10 browser render done 2026-10-12, see caveats there).
Check status with `bash scripts/check_event_backlog.sh` rather than trusting this header.

> **Not deployed.** The functions changes below (E2–E5) are local. The live `/event` still
> serves the old payload until `firebase deploy --only functions` runs; deploying the app is
> separate again (`make deploy-app-hosting`).

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

- [x] **E1 — Duplicate write layer** *(done 2026-08-22)*
  `FirestoreService` no longer touches Firestore for setlists or bands: the eight
  live methods delegate to `FirestoreSetlistRepository` / `FirestoreBandRepository`
  and six with no callers at all (`deleteBand`, `watchBandSetlists`,
  `getBandByInviteCode`, `isInviteCodeTaken`, `addUserToBand`, `removeUserFromBand`)
  were deleted rather than delegated.
  The two implementations were **not** equivalent — the service had write timeouts
  and typed permission messages the repositories lacked — so the timeout layer moved
  into `lib/repositories/firestore_timeout.dart` (`withFirestoreTimeout`) and both
  repositories now use it. `updateEventKitArea` and `saveBandBatch` moved onto the
  repository interfaces.
  **Metric:** `grep -c "collection('setlists')\|collection('bands')" lib/services/firestore_service.dart` → **0** (was 20). ✅

- [x] **E2 — Share tokens never expire** *(done 2026-08-22)*
  `SHARE_TTL_DAYS = 90`, stamped on create and honoured in `resolveToken` beside
  `revoked`. A share document with **no** `expiresAt` still works — links minted
  before expiry existed must not die on deploy day.
  **Metric:** an expired token and a garbage token return byte-identical errors
  (`fails an expired link and a garbage link identically`). ✅

- [x] **E3 — Suggestion flooding** *(done 2026-08-22)*
  `MAX_SUGGESTIONS_PER_TOKEN = 25`, counted on the share document and checked **inside
  a transaction** so two concurrent submissions cannot both slip past. Members are not
  counted — they write the setlist directly, so a limit on them would be theatre.
  **Metric:** the 26th from one token is rejected and not written; the 25th succeeds. ✅

- [x] **E4 — A guest cannot see their own suggestion's status** *(done 2026-08-22)*
  `getEventView` returns `mySuggestions` — matched on share token **and** uid, so a person
  keeps sight of what they asked for either side of signing in. Never echoes the token
  back. Rendered as "Your requests" on the guest page.
  **Metric:** an anonymous holder sees their own suggestion and its status; another
  token's are absent from the payload. ✅

- [x] **E5 — `getEventView` song fan-out is unbounded** *(done 2026-08-22)*
  `db.getAll(...)`, capped at `MAX_EVENT_SONGS = 100`, with `songsTruncated` on the payload.
  *(Instrumenting this: the SDK routes every `DocumentReference.get()` through `db.getAll`,
  so counting `getAll` calls also counts the setlist and band reads. The test counts only
  calls carrying song refs, and asserts one batch of ten.)*
  **Metric:** a 10-song event is **one** fan-out call of 10 refs; over the cap the payload
  says `songsTruncated: true` and the running order stays complete. ✅

- [x] **E6 — Client write wrappers untested** *(done 2026-08-22)*
  There was no seam: the constructor took a `FirebaseFunctions` but resolved
  `FirebaseFunctions.instance` eagerly, so building one in a unit test needed a real
  Firebase app. Added a `CallableInvoker` typedef and made the instance lazy.
  **Metric:** `createShare`, `revokeShare`, `claimShare`, `resolveSuggestion` and
  `submitSuggestion` each have tests through `eventShareServiceProvider` asserting the
  callable name and exact arguments. ✅

- [x] **E7 — Suggestions land where nobody looks** *(issue #187, done 2026-08-22)*
  Guests can submit today — live, deployed and tested — and **no band-side UI renders
  them**. `resolveSuggestion` exists in `lib/services/event_share_service.dart` and no
  screen calls it. Arguably a bug rather than deferred work.
  *(Do not grep for `suggestions` — 35 unrelated hits from song autocomplete, tags and
  stage gear. Grep for `resolveSuggestion` instead.)*
  Shipped: `lib/widgets/event_suggestions_inbox.dart`, fed by `setlistSuggestionsProvider`,
  rendered above the running order on a band setlist. Renders **nothing** when the inbox is
  empty. Accept/Decline are gated on band editor/admin — the callable refuses anyone else,
  so a plain member sees the request read-only instead of a button that fails.
  **Metric:** `resolveSuggestion` outside the service → **1** (was 0); widget tests cover
  accept, decline, the already-answered state and the read-only member. ✅

- [x] **E8 — Stale `guestUids` index still live** *(done 2026-08-22)*
  Diffed first, as required: live composite indexes matched the repo file **exactly**
  (10 vs 10, zero drift), so the only thing a `--force` deploy would have removed was this
  one override. Given that, `--force` was unnecessary — `gcloud firestore indexes fields
  update guestUids --collection-group=setlists --clear-exemption` removes just this field's
  exemption and cannot catch anything else in its blast radius. (The flag is
  `--clear-exemption`, not the `--clear-array-config`/`--clear-order` the docs suggest.)
  The command's long-running operation outlives a 2-minute client timeout; poll
  `gcloud firestore operations list` rather than trusting the CLI to return.
  **Metric:** the `COLLECTION_GROUP CONTAINS` index on `setlists.guestUids` is gone. The
  field now inherits default single-field indexing from `__default__/fields/*` like any
  unexempted field — and no document carries `guestUids` any more, so those stay empty. ✅

- [x] **E9 — `isDemoUserProvider` is permissive while loading** *(decided 2026-08-22)*
  Same class as the tri-state bug, inverted: for a *capability* provider `false` on loading
  denies (safe); for this *restriction* provider `false` permits. Gates 8 places including
  the join button. Pre-existing; the server callables are the real boundary, so it produces
  wrong doors rather than a leak. Fixing it naively flashes the demo banner for every real
  user on every cold start.
  **Metric:** a recorded decision (fix or accept, with reasoning) — and if fixed, a test that
  loading does not read as "not demo".

- [x] **E10 — The `/event` page has never rendered in a browser** *(done 2026-10-12, with caveats below)*
  Everything automatable was done on 2026-08-22; the render itself still needs a human,
  because `claude-in-chrome` is not connected in this environment and headless Chrome
  renders this app blank (CanvasKit).

  Verified without a browser:
  - the shell and its assets serve — `/` 200, `main.dart.js` 200 (6.2 MB),
    `flutter_bootstrap.js` 200, `manifest.json` 200
  - the **deployed** `getEventView` scopes both link kinds correctly against a throwaway
    event: the venue link returns titles with **no** `ourKey`/`ourBPM`/`sections`, no
    `stage`, no `rider`; the engineer link returns `stage` and `rider` and **still** no
    chart data

  **Done 2026-10-12** against the live app (still the old build; event functions and web
  build not yet deployed): both links paint. Venue link shows event, line-up, running order
  and "Suggest a change", with no stage/equipment/chart. Engineer link adds Stage plot and
  Equipment, still no chart. Scratch fixture torn down, scripts deleted.
  **Not checked:** the browser console, and claim-and-edit (the engineer page showed no edit
  controls on the live build). Re-test claim/edit after the next web deploy. Side note: the
  desktop layout shows the internal FlowGroove Wiki panel next to a guest's event page.

  ```bash
  cd functions
  node e10_scratch_event.js     # prints VENUE_LINK= and EDIT_LINK=
  # open https://app.flowgroove.app/#/event?t=<link> for each
  node e10_scratch_teardown.js  # deletes e10-scratch-band and its share tokens
  ```

  The fixture is a throwaway band with no members — it never touches a real setlist. Run
  the teardown when done; the scratch band is not one of yours and should not linger.

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
