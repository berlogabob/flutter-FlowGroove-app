# Pi Agent — Prompt for FlowGroove $t Fixes

**Role:** You are an expert Flutter/Firebase developer working on the FlowGroove music app.
**Workspace:** `/Users/berloga/Documents/GitHub/flutter_repsync_app`
**Plan Reference:** `Plan_LibraryUpdate.md` (canonical song + delta encoding)

---

## 📌 Context

The app uses:
- Flutter (Dart) for UI and business logic
- Firebase Firestore for data storage
- Firebase Functions for server-side logic (Node.js in `functions/`)
- Existing models: `CanonicalSong`, `SongDelta`, `LibrarySong`
- Repository: `FirestoreSongRepository` handles v1 (legacy full-song docs) and should be upgraded to v2 (linked library songs with delta)

Plan_LibraryUpdate.md describes a multi-phase migration. Many phases (1–4) are marked completed ([x]). Your tasks are the remaining unfinished ones (marked with [ ]).

---

## 🎯 Tasks

Implement these tasks **in order**:

### Task A: Part 4.2 — `ensureCanonicalSong` Firebase Callable Function (HIGH PRIORITY)

**Why needed:** The add-song flow needs a way to create/retrieve canonical records from MusicBrainz/ISRC/Spotify data. Currently missing entirely.

**Spec:**
- Create a callable Cloud Function: `ensureCanonicalSong`
- Location: `functions/index.js` (or new file `functions/src/canonical.js` if better)
- Input: `{ musicBrainzId?, isrc?, spotifyId?, title?, artist? }`
- Auth: Require authenticated user; reject demo users (`auth.token.demo === true` throws HEAVILY)
- Logic:
  1. If any external ID provided, search `canonical_songs` collection by that field (exact match). If found, return `{ canonicalSongId, revision: doc.canonicalRevision }`.
  2. If no external ID match but title+artist provided, normalize (lowercase, trim, remove punctuation) and query by `normalizedTitle` && `normalizedArtist`. If high-confidence match (>=0.9 similarity), return it.
  3. If still no match, create new canonical document **using Admin SDK** (not client). Generate `canonicalSongId` (UUID), set `schemaVersion`, `canonicalRevision: 1`, `source: 'manual'`, `status: 'active'`, `createdBy: auth.uid`, external IDs if any, normalized title/artist, `baseKey`, `baseBpm`, `baseSections`, `baseAccentBeats`, `baseRegularBeats`, `baseBeatModes`, `baseLinks`. Return new id/revision.
- Output: `{ canonicalSongId, revision }`

**Testing:**
- Write unit tests in `functions/test/canonical.test.js` using `firebase-functions-test` and `@firebase/rules-unit-testing` or simple mocks.
- Test cases: auth rejected for demo, exact external ID lookup, fuzzy title/artist match, creation path, non-auth rejected.

**Deliverable:** `functions/index.js` updated with `ensureCanonicalSong` + `functions/test/canonical.test.js` + README snippet on how to deploy/test locally.

---

### Task B: Part 0.2 — Regression Coverage for Repository Layer

**Why:** Before migration (Part 6), we need test safety net that ensures existing song CRUD, band songs, setlists, metronome, CSV continue to work after v2 changes.

**Current state:** Tests exist for some model-level things, but repository integration coverage is incomplete.

**Spec:**
- In `test/repositories/`, add/extend tests:
  - `test/repositories/song_repository_integration_test.dart`
  - Cover: `watchSongs(uid)` returns correct Song list (both legacy and v2 merged)
  - Cover: `saveSong` with and without `canonicalSongId` creates appropriate documents
  - Cover: `updateSong` updates delta and commit for v2 songs
  - Cover: Band songs: `watchBandSongs(bandId)`, `saveBandSong`, same v2 logic
  - Cover: Setlist stability: song IDs not changed after migration
  - Cover: Metronome settings persist via Song metadata
  - Cover: CSV import → uses repository path → produces canonical-linked songs when possible

**Use:** Firestore emulator (`firebase emulators:start --only firestore`) or mock Firestore with `mockito`/`fake_cloud_firestore`. Prefer emulator for integration realism.

**Deliverable:** New or extended test files with comprehensive scenarios, passing locally (`flutter test`).

---

### Task C: Part 6.2 — Backfill Dry-Run Script

**Why:** Before converting legacy songs to v2, we need to assess which songs can be auto-linked to canonical (high confidence) and which need review.

**Spec:**
- Create a script: `tool/backfill_dry_run.dart` (Dart CLI) or `scripts/backfill_dry_run.js` (Node).
- Run with: `dart run tool/backfill_dry_run.dart` or `node scripts/backfill_dry_run.js`
- Logic:
  - Connect to Firestore (use service account credentials from `GOOGLE_APPLICATION_CREDENTIALS` or emulator).
  - Iterate all legacy docs: `users/{uid}/songs/{songId}` and `bands/{bandId}/songs/{songId}` where `schemaVersion != 2`.
  - For each song:
    * Extract external IDs if present (`musicBrainzId`, `isrc`, `spotifyId`). Attempt lookup in `canonical_songs` by those fields. If found → classify as `linked` and store proposed `canonicalSongId`.
    * If no external IDs, compute `normalizedTitle` and `normalizedArtist` from song. Query `canonical_songs` where both match. Use fuzzy matching (Levenshtein <= 2 or exact normalized). If good match → classify as `review` (uncertain).
    * If no match → classify as `standalone` (keep as legacy).
  - Accumulate counts: total, linked, standalone, needs-review, failed.
  - Output: Print summary table + optionally write JSON report to `backfill_report_<timestamp>.json` containing per-song classification and proposed link.
- Do NOT write any data back in dry-run.

**Deliverable:** Executable script + sample output report + instructions on how to run against emulator or production (with read-only credentials).

---

### Task D: Part 6.3 — Backfill Write Run (safe batch)

**Prerequisite:** After dry-run validated and review list manually handled.

**Spec:**
- Script: `tool/backfill_write_run.dart` (Dart) or `functions/src/backfill.ts` (callable or one-off).
- Input: Accept a list of song document paths or all songs flagged `linked` from dry-run.
- Logic per song:
  - Read legacy song document.
  - Read corresponding canonical song document.
  - Compute delta using existing `SongDelta.computeDelta(canonical, legacySong)`.
  - Create new v2 LibrarySong document with fields:
    - `schemaVersion: 2`
    - `canonicalSongId`
    - `ownerType` (user or band)
    - `ownerId` (uid or bandId)
    - `baseRevision: canonical.canonicalRevision`
    - `delta: { ... }` (only changed fields)
    - `materialized: mergedSongAsJson` (full song for fallback)
    - `latestCommitId` (new commit doc id)
    - `createdAt`, `updatedAt: serverTimestamp()`
  - Create initial commit under `commits/{commitId}`: fields `parentCommitId: null`, `canonicalSongId`, `baseRevision`, `delta`, `operation: 'create'`, `authorId: system`, `message: 'Initial v2 migration'`, `createdAt`.
  - **Do NOT delete legacy document** — keep as backup. (Later cleanup after monitoring).
- Use Firestore batched writes or transactions for atomicity.
- Provide rollback instructions (delete v2 doc and commit).

**Deliverable:** Script with dry-run flag (preview only) and execute flag; clear logs; success/failure reporting.

---

### Task E: Revert Commit Operation

**Why:** Need ability to undo changes in commit history.

**Spec:**
- Extend commit model: no schema change, but add logic to create a revert commit.
- In LibrarySong repository or commit service, add `revertCommit(commitId, authorId, message)`.
  - Read the commit to revert.
  - Compute inverse delta (swap old/new values, or apply opposite transformation). For simple field changes, invert each field.
  - Create new commit with `operation: 'revert'`, `parentCommitId = current latestCommitId`, `delta: inverseDelta`, `message`.
  - Update LibrarySong `latestCommitId` and `materialized` to reflect reverted state.
- Optional UI: add button in commit history screen (if exists) to trigger revert.

**Deliverable:** Code changes + test for revert logic + brief doc.

---

## 🛠️ Workflow

1. Start with Task A (ensureCanonicalSong). Implement, test, document.
2. Then Task B (regression tests). Ensure existing tests pass; add missing.
3. Then Task C (dry-run). Validate against small dataset.
4. Then Task D (write-run). Execute carefully.
5. Then Task E (revert) if time permits.

Use `flutter test` for Dart code, `npm test` for Functions. Commit frequently with descriptive messages.

**Resources:**
- Existing models: `lib/models/canonical_song.dart`, `song_delta.dart`, `library_song.dart`
- Repository: `lib/repositories/firestore_song_repository.dart`
- Functions: `functions/index.js`
- Firestore rules: `firestore.rules` (paths for v2)
- Makefile: `make test`, `make functions-test`, `make deploy-functions`

---

**Start now.** Report progress after each task with a brief summary of what was done and next steps.
