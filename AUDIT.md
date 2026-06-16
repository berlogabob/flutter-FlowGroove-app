# FlowGroove — Codebase Audit & Improvement Plan

**Date:** June 15, 2026
**Version audited:** 0.13.4+195
**Scope:** Full repo — Flutter app (`lib/`), Firestore rules, Cloud Functions, storage rules, secrets/CI, repo hygiene
**Snapshot:** 267 Dart files (~59.7k LOC), 107 test files, 51 dependencies, Riverpod 3 + Firestore + Hive + go_router

> Note: `flutter analyze` could not be run in the audit sandbox (Flutter SDK not present). Static review was done by reading source. Run the analyzer in CI as a gate (see Phase 3).

---

## 1. Highlights — what's strong

The codebase is mature and disciplined. Several things stand out as above-average for an app this size:

- **Clean layered architecture.** `screens / widgets / providers / repositories / services / models / router / theme` with clear boundaries. Riverpod 3 for state, go_router for navigation. The layering described in `ARCHITECTURE.md` matches the actual tree.
- **Excellent typed error handling in the data layer.** `firestore_song_repository.dart` wraps every call in `try` and maps failures to a typed `ApiError` (`network`, `permission`, `notFound`), preserving stack traces and handling `TimeoutException` and `FirebaseException` distinctly. This is the gold standard and should be the template for the rest of the app.
- **Strong Firestore security rules.** Role-based + band-membership access, demo accounts locked to read-only, append-only commit history (`update, delete: if false`), explicit anti-privilege-escalation on `accessRole`, and schema validation on song writes. Genuinely well thought through.
- **Solid Cloud Functions.** `ensureCanonicalSong` checks auth, blocks demo users, and does transactional dedup with SHA-256 normalization — no race conditions, no unauthenticated writes.
- **Good secret hygiene posture.** `.env`/`.env.*` gitignored, web builds block client secrets via `kIsWeb` guards, the previously-tracked `web/config.js` is now gitignored (only `.template`/`.demo` remain), and a backend-proxy pattern exists for Spotify.
- **Real test suite.** 107 test files (~48 widget tests) with `mocktail` / `fake_cloud_firestore` mocks, plus Firestore-rules tests under `functions/test/`.
- **Very low tech-debt markers.** Only **1** real `TODO` in all of `lib/`. Strict analyzer config (`strict-casts`, `strict-inference`, `strict-raw-types`, `custom_lint`, `riverpod_lint`).
- **Modern dependencies.** Firebase, Riverpod, and tooling are on current major versions.

---

## 2. Findings — ranked by severity

### HIGH

**H1 — Firestore rules: admin-read check tests the wrong user.**
`firestore.rules` lines 249, 264, 273 use `isOwner(userId) || isAdminOrOwner(userId)`. `isAdminOrOwner(userId)` resolves the role of the **document owner** (`userId` is the path param), not the **requester** (`request.auth.uid`). Two consequences:

1. Real admins **cannot** read other users' docs/songs as intended (the feature is broken).
2. **Any authenticated user can read the profile and song library of any user whose `accessRole` is `admin`/`owner`** — an unintended data leak.

Fix — check the requester:

```
allow read: if isAuthenticated() && (isOwner(userId) || isAdminOrOwner(request.auth.uid));
```

Apply the same change at all three lines, and add a rules test asserting a non-admin cannot read an admin's user doc.

**H2 — The offline write queue is non-functional dead code.**
`WriteQueueService.enqueue()` is **never called anywhere** in `lib/`, and `flush()` only *returns* the pending entries — it never executes them. `SyncOrchestrator._onReconnect()` calls `flush()` then just `debugPrint`s the result and drops it (the code even comments "Actual execution happens in repository layer", but no such wiring exists). The "offline-first write queue" advertised in the docs does nothing.

Risk: misleading architecture, and a latent data-loss trap if anyone later routes writes through `enqueue()` expecting them to replay. (Today, offline writes still sync because the Firestore SDK has its own offline persistence — which is exactly why this custom queue is redundant.)

Fix — pick one and do it deliberately:
- **Remove** `write_queue_service.dart` + `SyncOrchestrator`'s flush wiring and rely on Firestore's built-in offline persistence (simplest, recommended), **or**
- **Finish it**: route repository mutations through `enqueue()` and have the orchestrator actually execute each `WriteEntry` against the right repository on reconnect, calling `complete()`/`fail()`.

### MEDIUM

**M2 — Telegram webhook has no secret-token verification.**
`functions/index.js` `exports.telegramWebhook` passes any `POST` body straight to `bot.handleUpdate(req.body)`. Anyone who discovers the URL can spoof Telegram updates (fake `/link`, `/unlink`, admin replies). Set a webhook secret when registering, and verify it:

```js
exports.telegramWebhook = functions.https.onRequest(async (req, res) => {
  const expected = WEBHOOK_SECRET.value();
  if (req.method === "POST") {
    if (req.get("X-Telegram-Bot-Api-Secret-Token") !== expected) {
      return res.status(401).send("unauthorized");
    }
    await bot.handleUpdate(req.body, res);
  } else if (req.method === "GET") {
    res.status(200).send("FlowGroove Bot");
  } else {
    res.status(405).send("Method Not Allowed");
  }
});
```

**M3 — Every band document is world-readable to any signed-in user.**
`/bands/{bandId}` uses `allow read: if isAuthenticated();`, exposing all band names, `memberUids`, `adminUids`, and join codes to every user. It's there to enable join-by-code, but it leaks full membership of every band. Consider a Cloud Function (or a minimal public `bandCodes` index) for code lookups, and restrict full band reads to members.

**M4 — Heavy `get()` use in rules drives cost and latency.**
`getUserRole()` and `getGlobalBand()` run on most reads/writes; each is a billed document read on the hot path. Move `accessRole` and `demo` onto **Firebase custom claims** (set from a Function) so rules can read `request.auth.token.accessRole` without a `get()`. This cuts both latency and read cost meaningfully at scale.

### LOW

**L1 — Storage rules allow unbounded profile uploads.** `storage.rules` permits `profile_pictures` writes with no size or type limit. Add:
```
allow write: if request.auth != null && request.auth.uid == userId
  && request.resource.size < 5 * 1024 * 1024
  && request.resource.contentType.matches('image/.*');
```

**L2 — God files.** 24 files exceed 500 lines; 7 exceed 800: `songs_list_screen.dart` (1151), `band_songs_screen.dart` (1109), `firestore_song_repository.dart` (1062), `tuner_provider.dart` (994), `analytics_service.dart` (930), `metronome_screen.dart` (846), `metronome_runtime_providers.dart` (835). These are hard to test and review. Extract sub-widgets and split notifiers/services by responsibility.

**L3 — Raw `print()` in production paths.** 27 `print()` calls (17 in `band_data_fixer.dart`, 9 in `profile_screen.dart`, 1 in `suggestion_card.dart`) write to the release console. Replace with `debugPrint` or a logger gated on `kDebugMode`.

**L4 — Silent error swallowing.** 10 empty `catch (_) {}` blocks (in models, `main.dart`, `home_screen.dart`, `the_band_screen.dart`) discard errors with no log. At minimum log them; ideally handle or rethrow.

**L5 — Repo hygiene.** 3 `.DS_Store` files are tracked despite being in `.gitignore` (`git rm --cached` them). Root is cluttered with generated/working artifacts (`firestore-debug.log`, `flutter_01.log`, ad-hoc `*_report.md`, `Grok-*.json`); move reports under `docs/` and keep logs out of the working tree.

**L6 — Dependency surface.** ~60k LOC and 51 direct deps is a large maintenance/bundle surface. Run `flutter pub outdated` and prune unused packages periodically.

---

## 3. Improvement & fix plan (phased)

### Phase 0 — Security hotfixes (this week)
- **H1** Fix the three `isAdminOrOwner(userId)` → `isAdminOrOwner(request.auth.uid)` lines; add a rules test; `firebase deploy --only firestore:rules`.
- **M2** Add Telegram webhook secret-token verification; re-register the webhook with the secret.
- **L1** Add size/content-type limits to storage rules; deploy.

### Phase 1 — Correctness (1–2 weeks)
- **H2** Decide write queue: remove it (recommended) or finish the execute-on-reconnect path. Update `ARCHITECTURE.md` to match reality.
- **M3** Scope band reads to members; move join-by-code to a Function or public code index.
- **L4** Replace empty catches with logging/handling.

### Phase 2 — Cost & performance
- **M4** Move `accessRole`/`demo` to custom claims; strip `get()` calls from hot-path rules.
- Add Firestore read/cost telemetry to confirm the reduction.

### Phase 3 — Maintainability
- **L2** Split the 7 god files into widgets/sub-notifiers; add focused tests.
- **L3** Swap `print()` for guarded logging.
- **L5/L6** Repo cleanup; `pub outdated` prune.
- Add `flutter analyze` (and `dart format --set-exit-if-changed`) as a CI gate and burn down the existing lint backlog noted in `docs/project-audit-2026-04-24.md`.

### Suggested quick wins (low effort, high value)
H1, M2, L1, L3, L5 are all small, self-contained changes with outsized benefit — do them first.

---

## 4. Already resolved since the April 2026 audit
- `web/config.js` is no longer tracked (only `.template`/`.demo`), and is now gitignored — the prior "failing security audit" cause is fixed.
- `.env` and variants are correctly gitignored; no live secrets found in tracked files.
