# FlowGroove - ZooFix Tasks for Pi Agent

**Project:** FlowGroove (Flutter music app)  
**Repo:** /Users/berloga/Documents/GitHub/flutter_repsync_app  
**Plan:** Plan_LibraryUpdate.md — Canonical Song + Delta Encoding  

---

## 📋 Tasks To Fix ($t)

### Task 1: Part 0.2 — Regression Coverage
**Status:** Incomplete (partial coverage exists)
**Goal:** Implement repository integration tests before storage changes
**Details:**
- Cover `Song.fromJson`, save/update/delete operations
- Band songs flow (`bands/{bandId}/songs`)
- Setlists by `songIds` references
- Metronome settings persistence
- CSV import/export round-trip
**Specific gap:** "repository integration coverage still pending" — needs full repository layer tests using Firestore emulator or mocked repository.
**Deliverable:** Add test files under `test/repository/` that exercise the complete Song repository lifecycle (create, read, update, delete) for both user and band songs, verifying that setlist references remain stable.

---

### Task 2: Part 4.2 — ensureCanonicalSong Firebase Callable
**Status:** All 6 micro-steps unchecked (🚨 blocking)
**Goal:** Implement `ensureCanonicalSong` function in `functions/`
**Behaviour:**
1. Auth required — reject demo users (`request.auth.token.demo === true`)
2. Accept input: `{ musicBrainzId?, isrc?, spotifyId?, title?, artist? }`
3. Search strategy:
   - First: exact match on any provided external ID (MusicBrainz/ISRC/Spotify) → return existing canonical
   - Second: normalized title+artist fuzzy match (threshold TBD)
4. Create new canonical only via Admin SDK (not client write)
5. Return `{ canonicalSongId, revision: canonicalRevision }`
**Location:** `functions/src/canonical.ts` (or existing functions structure)
**Deploy:** After testing with `firebase emulators:exec` or local functions shell
**Deliverable:** Working function + unit/integration tests in `functions/test/`

---

### Task 3: Part 6.2 — Backfill Dry-Run Script
**Status:** All 5 micro-tasks unchecked
**Goal:** Build migration script with dry-run output (no mutations)
**Details:**
- Iterate all legacy songs in `users/{uid}/songs` and `bands/{bandId}/songs` where `schemaVersion` missing or =1
- For each song:
  1. Try external IDs (MusicBrainz, ISRC, Spotify) → lookup in `canonical_songs`
  2. If no match, compute normalized title/artist and fuzzy-search canonical
  3. Classify: `high-confidence` (exact external ID match), `review` (fuzzy match < threshold), `standalone` (no match)
- Do NOT mutate any documents in dry-run
- Produce summary report: counts for linked, standalone, needs-review, failed + list of review candidates
**Deliverable:** Script `scripts/backfill_dry_run.ts` (Node) or `tool/backfill.dart` (Dart) + sample output

---

### Task 4: Part 6.3 — Backfill Write Run (after dry-run validation)
**Prerequisite:** Dry-run produces acceptable linkage
**Goal:** Batch-convert high-confidence matches to v2 library songs
**Details:**
- Preserve document IDs
- Write `schemaVersion: 2`, `canonicalSongId`, `delta`, `materialized`, `latestCommitId`
- Create initial commit under `commits/{auto-generated-id}`
- Keep every user-visible field recoverable (do not delete legacy fields)
- Do not delete original documents until monitoring passes
**Deliverable:** Safe batch migration function (Firebase Function or one-off script) + rollback instructions

---

### Task 5: Revert Commit Operation
**Status:** Pending (line 45)
**Goal:** Implement revert functionality in commit history model
**Details:**
- Add `revertCommit(parentCommitId, authorId, message)` that creates a new commit with inverse delta
- Update `LibrarySong.latestCommitId` to point to revert commit
- Preserve original history (linear chain)
- UI: expose revert action on commit history screen (if exists)
**Deliverable:** Commit revert logic + basic UI integration

---

## 🎯 Prioritization Order
1. Task 2 (Part 4.2) — needed to add new songs from MusicBrainz/canonical
2. Task 1 (Part 0.2) — safety net before Part 6 migration
3. Task 3 (Part 6.2) — prepare migration
4. Task 4 (depends on 3) — execute migration
5. Task 5 — post-migration improvement

---

## 📁 Project Structure Notes
- **Flutter app:** `lib/` — models (`song.dart`, `canonical_song.dart`, `song_delta.dart`), repositories (`repositories.dart`, `firestore_song_repository.dart`)
- **Firebase Functions:** `functions/` — callable endpoints, Firestore triggers
- **Rules:** `firestore.rules` — v2 paths: `users/{uid}/songs`, `bands/{bandId}/songs`, `canonical_songs`
- **Tests:** Flutter: `test/`, Functions: `functions/test/`
- **CLI:** Use `make` targets in `Makefile` (check existing: `make test`, `make functions-test`, `make deploy-functions`)

---

## ⚙️ Command Reference
```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app

# Flutter tests (unit + widget)
flutter test
flutter test --reporter expanded

# Repository integration tests (with emulator)
flutter test integration_test/

# Analyze
flutter analyze

# Firebase Functions (local)
cd functions && npm test
firebase emulators:start --only functions,firestore

# Deploy function after validation
firebase deploy --only functions:ensureCanonicalSong
```

---

**Status:** Ready for pi agent execution.  
**Next:** Run `pi [directives from this file]` to implement tasks incrementally.
